import 'coach_models.dart';
import 'game_review_models.dart';

// ================================================================
// محرك الجمل الجاهزة لمدرب الشطرنج.
//
// الجمل تُختار من بيانات المحرك (Stockfish) فقط: تصنيف النقلة، الخسارة،
// أفضل نقلة، المرحلة، ونوع النقلة (أخذ / كش / تبييت / ترقية / قطعة)،
// ثم تُصاغ بحسب مستوى اللاعب (مبتدئ → خبير) ولغته (عربي / إنجليزي).
// الاختيار بين الصيغ المتعددة ثابت لنفس النقلة (لا عشوائية)، ومتنوّع
// بين النقلات المختلفة.
// ================================================================

/// خصائص نقلة مستخرجة من صيغة SAN.
class _Feat {
  final bool capture;
  final bool check;
  final bool mate;
  final bool castle;
  final bool promo;

  /// K Q R B N P
  final String piece;

  const _Feat({
    required this.capture,
    required this.check,
    required this.mate,
    required this.castle,
    required this.promo,
    required this.piece,
  });

  bool get tactical => capture || check || mate || promo;
}

_Feat _feat(String san) {
  final s = san.trim();
  final castle = s.startsWith('O-O');
  final first = s.isEmpty ? 'P' : s[0];

  return _Feat(
    capture: s.contains('x'),
    check: s.contains('+'),
    mate: s.contains('#'),
    castle: castle,
    promo: s.contains('='),
    piece: castle ? 'K' : ('KQRBN'.contains(first) ? first : 'P'),
  );
}

class CoachTemplateEngine {
  CoachTemplateEngine._();

  // ================================================================
  // شرح نقلة
  // ================================================================

  static CoachExplanation explainMove(
    CoachMoveInput i, {
    required CoachLevel level,
    required CoachLang lang,
    bool revealBest = false,
    String? personalNote,
  }) {
    final ar = lang == CoachLang.ar;
    final g = _group(i.quality);
    final seed = _seed(i);
    final played = _feat(i.san);
    final best = _feat(i.bestMove);
    final isErr = _isError(i.quality);
    final detailed =
        level == CoachLevel.advanced || level == CoachLevel.expert;

    final parts = <String>[];

    parts.add(_did(i.san, played, ar));
    parts.add(_pick((ar ? _whyAr : _whyEn)[g]!, seed + 1));

    if (isErr) {
      final reason = _reason(i, played, best, ar, seed);

      if (reason != null) parts.add(reason);

      final swing = _swing(i, ar);

      if (swing != null) parts.add(swing);

      if (i.evalLoss > 0.05) {
        final loss = i.evalLoss.toStringAsFixed(1);

        if (detailed) {
          parts.add(
            ar
                ? 'الخسارة التقديرية: $loss بيدق '
                    '(${_fmt(i.evalBefore)} ← ${_fmt(i.evalAfter)}).'
                : 'Estimated loss: $loss pawns '
                    '(${_fmt(i.evalBefore)} → ${_fmt(i.evalAfter)}).',
          );
        } else if (level == CoachLevel.intermediate) {
          parts.add(
            ar
                ? 'كلّفتك هذه النقلة نحو $loss بيدق من أفضليتك.'
                : 'This move cost you about $loss pawns of advantage.',
          );
        }
      }
    } else if (level != CoachLevel.beginner) {
      parts.add(
        ar
            ? 'موقفك الآن: ${_stateAr[_state(i.evalAfter)]}.'
            : 'Your position now: ${_stateEn[_state(i.evalAfter)]}.',
      );
    }

    final verdict = _tablebase(i.tablebaseVerdict, ar);

    if (verdict != null) parts.add(verdict);

    String? better;

    if (revealBest && isErr && i.bestMove.isNotEmpty) {
      better = i.bestMove;

      parts.add(_bestSentence(i.bestMove, best, ar));

      if (detailed && i.principalVariation.length > 1) {
        parts.add(
          ar
              ? 'الخط الرئيسي: ${i.principalVariation.join(' ')}.'
              : 'Main line: ${i.principalVariation.join(' ')}.',
        );
      } else if (level == CoachLevel.beginner) {
        parts.add(
          ar
              ? 'جرّب أن تلعبها على الرقعة وشاهد الفرق.'
              : 'Try playing it on the board and see the difference.',
        );
      }
    }

    var lesson = _pick((ar ? _lessonAr : _lessonEn)[g]!, seed + 2);

    if (personalNote != null && personalNote.isNotEmpty) {
      lesson = '$lesson\n🎓 $personalNote';
    }

    return CoachExplanation(
      title: (ar ? _titleAr : _titleEn)[g]!,
      summary: _pick((ar ? _sumAr : _sumEn)[g]!, seed),
      explanation: parts.join(' '),
      betterMove: better,
      idea: _idea(i, best, isErr, ar, seed),
      lesson: lesson,
    );
  }

  // ================================================================
  // شرح وضعية
  // ================================================================

  static CoachExplanation explainPosition(
    CoachPositionInput p, {
    required CoachLevel level,
    required CoachLang lang,
  }) {
    final ar = lang == CoachLang.ar;
    final e = p.evalPawns;
    final a = e.abs();
    final seed = p.fen.length + p.bestMove.length;

    final who = p.sideToMove == 'white'
        ? (ar ? 'الأبيض' : 'White')
        : (ar ? 'الأسود' : 'Black');

    final leader =
        e > 0 ? (ar ? 'الأبيض' : 'White') : (ar ? 'الأسود' : 'Black');

    String state;

    if (a >= 90) {
      state = ar
          ? 'يوجد كش مات قسري لصالح $leader.'
          : 'There is a forced mate for $leader.';
    } else if (a < 0.3) {
      state = ar
          ? 'الوضعية متوازنة تقريبًا.'
          : 'The position is roughly equal.';
    } else if (a < 1) {
      state = ar
          ? 'أفضلية طفيفة لدى $leader (${_fmt(e)}).'
          : 'A slight edge for $leader (${_fmt(e)}).';
    } else if (a < 3) {
      state = ar
          ? 'أفضلية واضحة لدى $leader (${_fmt(e)}).'
          : 'A clear advantage for $leader (${_fmt(e)}).';
    } else {
      state = ar
          ? 'أفضلية حاسمة لدى $leader (${_fmt(e)}).'
          : 'A decisive advantage for $leader (${_fmt(e)}).';
    }

    final best = _feat(p.bestMove);
    final line = p.principalVariation.take(4).join(' ');

    final parts = <String>[
      ar ? 'الدور على $who.' : '$who to move.',
      ar
          ? 'أفضل نقلة حسب المحرك: ${p.bestMove}${_bestDescAr(best)}.'
          : 'Engine best move: ${p.bestMove}${_bestDescEn(best)}.',
    ];

    if (line.isNotEmpty && level != CoachLevel.beginner) {
      parts.add(ar ? 'الخط المقترح: $line.' : 'Suggested line: $line.');
    }

    if (best.tactical) {
      parts.add(
        ar
            ? 'الوضعية تكتيكية؛ احسب الكشوف والأخذات بدقة.'
            : 'The position is tactical; calculate checks and captures.',
      );
    }

    return CoachExplanation(
      title: ar ? '🎓 تحليل الوضعية' : '🎓 Position analysis',
      summary: state,
      explanation: parts.join(' '),
      betterMove: p.bestMove,
      idea: _pick((ar ? _phaseAr : _phaseEn)[_phase(p.phase)]!, seed),
      lesson: _pick(ar ? _posLessonAr : _posLessonEn, seed),
    );
  }

  // ================================================================
  // ملخص مباراة
  // ================================================================

  static CoachExplanation explainGame(
    List<CoachMoveInput> moves, {
    required CoachLevel level,
    required CoachLang lang,
    String? personalNote,
  }) {
    final ar = lang == CoachLang.ar;

    var best = 0;
    var brilliant = 0;
    var inacc = 0;
    var mistakes = 0;
    var blunders = 0;
    var loss = 0.0;

    final errByPhase = <String, int>{
      'opening': 0,
      'middlegame': 0,
      'endgame': 0,
    };

    for (final m in moves) {
      loss += m.evalLoss;

      switch (m.quality) {
        case MoveQuality.best:
        case MoveQuality.great:
          best++;
        case MoveQuality.brilliant:
          brilliant++;
          best++;
        case MoveQuality.inaccuracy:
          inacc++;
        case MoveQuality.mistake:
        case MoveQuality.miss:
          mistakes++;
        case MoveQuality.blunder:
          blunders++;
        default:
          break;
      }

      if (_isError(m.quality)) {
        final k = errByPhase.containsKey(m.phase) ? m.phase : 'middlegame';

        errByPhase[k] = (errByPhase[k] ?? 0) + 1;
      }
    }

    final n = moves.length;
    final acpl = n == 0 ? 0 : (loss * 100 / n).round();

    final summary = ar
        ? 'لعبت $n نقلة: $best قوية، $inacc غير دقيقة، $mistakes أخطاء، '
            '$blunders أخطاء فادحة.'
        : 'You played $n moves: $best strong, $inacc inaccurate, '
            '$mistakes mistakes, $blunders blunders.';

    final parts = <String>[];

    // مستوى الأداء حسب متوسط الخسارة.
    String grade;

    if (acpl <= 20) {
      grade = ar ? 'أداء ممتاز' : 'excellent play';
    } else if (acpl <= 40) {
      grade = ar ? 'أداء جيد جدًا' : 'very good play';
    } else if (acpl <= 70) {
      grade = ar ? 'أداء جيد' : 'good play';
    } else if (acpl <= 120) {
      grade = ar ? 'أداء متوسط' : 'average play';
    } else {
      grade = ar ? 'أداء يحتاج تحسينًا' : 'play that needs work';
    }

    parts.add(ar ? 'التقييم العام: $grade.' : 'Overall: $grade.');

    if (level == CoachLevel.advanced || level == CoachLevel.expert) {
      parts.add(
        ar
            ? 'متوسط خسارة النقلة (ACPL): $acpl سنتيبون.'
            : 'Average centipawn loss (ACPL): $acpl.',
      );
    }

    if (brilliant > 0) {
      parts.add(
        ar
            ? 'سجّلت $brilliant نقلة Brilliant — رؤية رائعة!'
            : 'You scored $brilliant Brilliant move(s) — great vision!',
      );
    }

    if (n > 0 && best / n >= 0.5) {
      parts.add(
        ar
            ? 'اخترت أفضل نقلة في أغلب المواقف.'
            : 'You found the best move in most positions.',
      );
    }

    // أكثر مرحلة فيها أخطاء.
    final totalErr = inacc + mistakes + blunders;

    if (totalErr >= 3) {
      final worst = errByPhase.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );

      if (worst.value * 2 >= totalErr) {
        const phaseAr = {
          'opening': 'الافتتاح',
          'middlegame': 'الوسط',
          'endgame': 'النهاية',
        };

        const phaseEn = {
          'opening': 'the opening',
          'middlegame': 'the middlegame',
          'endgame': 'the endgame',
        };

        parts.add(
          ar
              ? 'أكثر أخطائك كانت في ${phaseAr[worst.key]}.'
              : 'Most of your errors came in ${phaseEn[worst.key]}.',
        );
      }
    }

    // نصيحة حسب أسوأ نوع خطأ.
    String advice;

    if (blunders > 0) {
      advice = ar
          ? 'ابدأ بمراجعة أخطائك الفادحة؛ ففيها أكبر مكسب. وجعل فحص '
              'التهديدات عادة قبل كل نقلة يحل أغلبها.'
          : 'Review your blunders first; that is where the gain is. A '
              'threat check before every move fixes most of them.';
    } else if (mistakes > 0) {
      advice = ar
          ? 'قارن بين نقلتين على الأقل في المواقف الحرجة قبل أن تقرر.'
          : 'Compare at least two candidate moves in critical positions.';
    } else if (inacc > 0) {
      advice = ar
          ? 'أخطاؤك صغيرة؛ ركّز على تحسين التفاصيل وتفعيل قطعك الأضعف.'
          : 'Your errors are small; polish the details and activate '
              'your weakest piece.';
    } else {
      advice = ar
          ? 'لعبة نظيفة بلا أخطاء تُذكر، أحسنت! حافظ على هذا المستوى.'
          : 'A clean game with no real errors — well done! Keep it up.';
    }

    return CoachExplanation(
      title: ar ? '🎓 ملخص المباراة' : '🎓 Game summary',
      summary: summary,
      explanation: parts.join(' '),
      lesson: (personalNote != null && personalNote.isNotEmpty)
          ? '$advice\n🎓 $personalNote'
          : advice,
    );
  }

  // ================================================================
  // مساعدات
  // ================================================================

  static String _fmt(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}';

  static int _seed(CoachMoveInput i) {
    var h = i.moveNumber;

    for (final c in i.san.codeUnits) {
      h = (h * 31 + c) % 100003;
    }

    return h;
  }

  static String _pick(List<String> options, int seed) =>
      options[seed.abs() % options.length];

  static bool _isError(MoveQuality q) =>
      q == MoveQuality.inaccuracy ||
      q == MoveQuality.mistake ||
      q == MoveQuality.miss ||
      q == MoveQuality.blunder;

  static String _phase(String p) =>
      (p == 'opening' || p == 'endgame') ? p : 'middlegame';

  static String _group(MoveQuality q) {
    switch (q) {
      case MoveQuality.brilliant:
        return 'brilliant';
      case MoveQuality.great:
        return 'great';
      case MoveQuality.best:
        return 'best';
      case MoveQuality.excellent:
        return 'excellent';
      case MoveQuality.good:
      case MoveQuality.book:
        return 'good';
      case MoveQuality.inaccuracy:
        return 'inaccuracy';
      case MoveQuality.mistake:
        return 'mistake';
      case MoveQuality.miss:
        return 'miss';
      case MoveQuality.blunder:
        return 'blunder';
    }
  }

  /// حالة اللاعب من التقييم (منظوره): winning / better / equal /
  /// worse / losing.
  static String _state(double e) {
    if (e >= 2.5) return 'winning';
    if (e >= 0.8) return 'better';
    if (e > -0.8) return 'equal';
    if (e > -2.5) return 'worse';

    return 'losing';
  }

  static String? _swing(CoachMoveInput i, bool ar) {
    final a = _state(i.evalBefore);
    final b = _state(i.evalAfter);

    if (a != b) {
      return ar
          ? 'كنت ${_stateAr[a]} وأصبحت ${_stateAr[b]}.'
          : 'You were ${_stateEn[a]} and became ${_stateEn[b]}.';
    }

    if (i.evalLoss >= 0.3) {
      return ar
          ? 'ما زال موقفك (${_stateAr[b]}) لكنه أصبح أصعب.'
          : 'Your position (${_stateEn[b]}) is unchanged but harder now.';
    }

    return null;
  }

  /// وصف ما فعله اللاعب.
  static String _did(String san, _Feat f, bool ar) {
    if (ar) {
      if (f.mate) return 'لعبت $san وهذا كش مات!';
      if (f.castle) return 'قمت بتبييت الملك ($san).';
      if (f.promo && f.capture) return 'رقّيت البيدق مع أخذ قطعة ($san).';
      if (f.promo) return 'رقّيت البيدق ($san).';
      if (f.capture && f.check) {
        return 'أخذت قطعة ${_pieceByAr[f.piece]} مع كش ($san).';
      }
      if (f.capture) return 'أخذت قطعة ${_pieceByAr[f.piece]} ($san).';
      if (f.check) return 'أعطيت كشًا ${_pieceByAr[f.piece]} ($san).';

      return 'حرّكت ${_pieceAr[f.piece]} ($san).';
    }

    if (f.mate) return 'You played $san — checkmate!';
    if (f.castle) return 'You castled ($san).';
    if (f.promo && f.capture) return 'You promoted with a capture ($san).';
    if (f.promo) return 'You promoted the pawn ($san).';
    if (f.capture && f.check) {
      return 'You captured with the ${_pieceEn[f.piece]} and gave check '
          '($san).';
    }
    if (f.capture) return 'You captured with the ${_pieceEn[f.piece]} ($san).';
    if (f.check) return 'You gave check with the ${_pieceEn[f.piece]} ($san).';

    return 'You moved the ${_pieceEn[f.piece]} ($san).';
  }

  /// سبب الخطأ من نوع النقلة الملعوبة مقابل أفضل نقلة.
  static String? _reason(
    CoachMoveInput i,
    _Feat played,
    _Feat best,
    bool ar,
    int seed,
  ) {
    final ph = _phase(i.phase);
    final hasBest = i.bestMove.isNotEmpty;

    if (hasBest) {
      if (best.mate && !played.mate) {
        return ar
            ? 'كان هناك كش مات في الوضعية — ابحث دائمًا عن الكشوف أولًا!'
            : 'There was a checkmate in the position — always look for '
                'checks first!';
      }

      if (best.promo && !played.promo) {
        return ar
            ? 'كان بالإمكان ترقية البيدق فورًا.'
            : 'You could have promoted the pawn right away.';
      }

      if (best.capture && !played.capture) {
        return ar
            ? 'كان هناك أخذ أقوى يكسب المادة أو المبادرة.'
            : 'There was a stronger capture winning material or the '
                'initiative.';
      }

      if (best.check && !played.check) {
        return ar
            ? 'كان هناك كش قوي يفرض ردّ الخصم.'
            : 'There was a strong check that forces your opponent’s reply.';
      }

      if (best.castle && !played.castle && ph == 'opening') {
        return ar
            ? 'كان تبييت الملك أولى لتأمينه وربط الرخين.'
            : 'Castling was better to secure the king and connect the '
                'rooks.';
      }
    }

    if (played.piece == 'Q' && ph == 'opening' && !played.capture) {
      return ar
          ? 'تحريك الوزير مبكرًا يعرّضه للمطاردة ويضيّع وقت التطوير.'
          : 'Moving the queen early exposes it to harassment and wastes '
              'development time.';
    }

    if (played.piece == 'K' && !played.castle && ph != 'endgame') {
      return ar
          ? 'تحريك الملك بلا داعٍ يُضعف أمانه.'
          : 'Moving the king without need weakens its safety.';
    }

    if (played.piece == 'P' && ph == 'opening' && !played.capture) {
      return ar
          ? 'كثرة نقلات البيادق في الافتتاح تؤخر تطوير القطع.'
          : 'Too many pawn moves in the opening delay piece development.';
    }

    if (played.capture) {
      return ar
          ? 'الأخذ لم يكن في صالحك هنا؛ ربما استعاد الخصم المادة أو كسب '
              'المبادرة.'
          : 'The capture did not work in your favour here; your opponent '
              'may regain material or the initiative.';
    }

    if (played.check) {
      return ar
          ? 'الكش لم يحقق شيئًا ملموسًا وأضاع فرصة أفضل.'
          : 'The check achieved nothing concrete and missed a better '
              'chance.';
    }

    if (ph == 'endgame') {
      return ar
          ? 'في النهايات الدقة مطلوبة؛ تحقق من نشاط الملك وسباق البيادق.'
          : 'Endgames demand precision; check king activity and the pawn '
              'race.';
    }

    return _pick(ar ? _genericAr : _genericEn, seed + 3);
  }

  static String _bestDescAr(_Feat f) {
    if (f.mate) return ' (كش مات)';
    if (f.promo) return ' (ترقية)';
    if (f.capture && f.check) return ' (أخذ مع كش)';
    if (f.capture) return ' (أخذ)';
    if (f.check) return ' (كش)';
    if (f.castle) return ' (تبييت)';

    return '';
  }

  static String _bestDescEn(_Feat f) {
    if (f.mate) return ' (checkmate)';
    if (f.promo) return ' (promotion)';
    if (f.capture && f.check) return ' (capture with check)';
    if (f.capture) return ' (capture)';
    if (f.check) return ' (check)';
    if (f.castle) return ' (castling)';

    return '';
  }

  static String _bestSentence(String san, _Feat f, bool ar) {
    return ar
        ? 'كانت $san أقوى في هذه الوضعية${_bestDescAr(f)}.'
        : '$san was stronger in this position${_bestDescEn(f)}.';
  }

  static String? _idea(
    CoachMoveInput i,
    _Feat best,
    bool isErr,
    bool ar,
    int seed,
  ) {
    if (isErr && best.tactical) {
      return ar
          ? 'الفكرة تكتيكية: ابحث عن الكشوف والأخذات والتهديدات أولًا.'
          : 'The idea is tactical: look for checks, captures and threats '
              'first.';
    }

    return _pick((ar ? _phaseAr : _phaseEn)[_phase(i.phase)]!, seed);
  }

  static String? _tablebase(String? v, bool ar) {
    switch (v) {
      case 'lostWin':
        return ar
            ? 'حسب Tablebase: تحوّلت الوضعية من رابحة إلى خاسرة.'
            : 'Tablebase: the position went from winning to losing.';
      case 'missedWin':
        return ar
            ? 'حسب Tablebase: فاتك الفوز وصارت الوضعية تعادلًا.'
            : 'Tablebase: you let the win slip to a draw.';
      case 'blunder':
        return ar
            ? 'حسب Tablebase: تحوّل التعادل إلى خسارة.'
            : 'Tablebase: a draw turned into a loss.';
    }

    return null;
  }

  // ================================================================
  // الجمل
  // ================================================================

  static const Map<String, String> _pieceAr = {
    'K': 'الملك',
    'Q': 'الوزير',
    'R': 'الرخ',
    'B': 'الفيل',
    'N': 'الحصان',
    'P': 'البيدق',
  };

  static const Map<String, String> _pieceByAr = {
    'K': 'بالملك',
    'Q': 'بالوزير',
    'R': 'بالرخ',
    'B': 'بالفيل',
    'N': 'بالحصان',
    'P': 'بالبيدق',
  };

  static const Map<String, String> _pieceEn = {
    'K': 'king',
    'Q': 'queen',
    'R': 'rook',
    'B': 'bishop',
    'N': 'knight',
    'P': 'pawn',
  };

  static const Map<String, String> _stateAr = {
    'winning': 'رابحًا',
    'better': 'متفوقًا',
    'equal': 'متكافئًا',
    'worse': 'أضعف قليلًا',
    'losing': 'في موقف خاسر',
  };

  static const Map<String, String> _stateEn = {
    'winning': 'winning',
    'better': 'better',
    'equal': 'equal',
    'worse': 'slightly worse',
    'losing': 'losing',
  };

  static const Map<String, String> _titleAr = {
    'brilliant': '✨ نقلة رائعة',
    'great': '🟢 نقلة قوية جدًا',
    'best': '🟢 أفضل نقلة',
    'excellent': '🟢 نقلة ممتازة',
    'good': '🟢 نقلة جيدة',
    'inaccuracy': '🟡 نقلة غير دقيقة',
    'mistake': '🟠 خطأ',
    'miss': '🟠 فرصة ضائعة',
    'blunder': '🔴 خطأ فادح',
  };

  static const Map<String, String> _titleEn = {
    'brilliant': '✨ Brilliant move',
    'great': '🟢 Great move',
    'best': '🟢 Best move',
    'excellent': '🟢 Excellent',
    'good': '🟢 Good move',
    'inaccuracy': '🟡 Inaccuracy',
    'mistake': '🟠 Mistake',
    'miss': '🟠 Missed opportunity',
    'blunder': '🔴 Blunder',
  };

  static const Map<String, List<String>> _sumAr = {
    'brilliant': [
      'وجدت نقلة استثنائية!',
      'نقلة لامعة يصعب العثور عليها!',
      'رؤية رائعة — هذه نقلة Brilliant.',
    ],
    'great': [
      'نقلة حاسمة في الوضعية.',
      'وجدت النقلة التي تتطلبها الوضعية.',
      'اختيار ممتاز في لحظة مهمة.',
    ],
    'best': [
      'هذه أفضل نقلة في الوضعية.',
      'طابقت اختيار المحرك تمامًا.',
      'أفضل نقلة ممكنة — أحسنت!',
    ],
    'excellent': [
      'نقلة قريبة جدًا من الأفضل.',
      'اختيار ممتاز وآمن.',
      'نقلة قوية حافظت على موقفك.',
    ],
    'good': [
      'نقلة مقبولة وآمنة.',
      'نقلة جيدة، وإن وُجد خيار أدق.',
      'لعبت بشكل سليم.',
    ],
    'inaccuracy': [
      'النقلة جيدة لكن هناك أدق منها.',
      'نقلة غير دقيقة قليلًا.',
      'كان بالإمكان تحسينها.',
    ],
    'mistake': [
      'هذه النقلة أضعفت موقفك.',
      'خطأ أعطى الخصم أفضلية واضحة.',
      'نقلة كلّفتك جزءًا مهمًا من موقفك.',
    ],
    'miss': [
      'فاتتك فرصة قوية.',
      'كانت هناك فرصة أفضل لم تُستغل.',
      'تجاوزت استمرارًا أقوى بكثير.',
    ],
    'blunder': [
      'هذه النقلة غيّرت مسار المباراة.',
      'خطأ فادح قلب الموقف.',
      'نقلة خطيرة سلّمت الخصم الأفضلية.',
    ],
  };

  static const Map<String, List<String>> _sumEn = {
    'brilliant': [
      'You found an exceptional move!',
      'A dazzling move that is hard to find!',
      'Great vision — that is a Brilliant move.',
    ],
    'great': [
      'A critical move in the position.',
      'You found what the position demanded.',
      'An excellent choice at an important moment.',
    ],
    'best': [
      'This is the best move here.',
      'You matched the engine’s top choice.',
      'The best move possible — well done!',
    ],
    'excellent': [
      'Very close to the best move.',
      'An excellent and safe choice.',
      'A strong move that kept your position.',
    ],
    'good': [
      'A solid, safe move.',
      'A good move, though a sharper one existed.',
      'You played soundly.',
    ],
    'inaccuracy': [
      'Good, but there was a sharper move.',
      'A slightly inaccurate move.',
      'It could have been improved.',
    ],
    'mistake': [
      'This move weakened your position.',
      'A mistake that gave your opponent a clear edge.',
      'A move that cost you a good part of your position.',
    ],
    'miss': [
      'You missed a strong chance.',
      'A better opportunity went unused.',
      'You skipped a much stronger continuation.',
    ],
    'blunder': [
      'This move changed the course of the game.',
      'A blunder that flipped the position.',
      'A dangerous move that handed over the advantage.',
    ],
  };

  static const Map<String, List<String>> _whyAr = {
    'brilliant': [
      'هي نقلة يصعب العثور عليها وتحافظ على موقفك بقوة.',
      'غالبًا تحمل فكرة تكتيكية عميقة أو تضحية مدروسة.',
    ],
    'great': [
      'وجدت النقلة الوحيدة تقريبًا التي تحافظ على موقفك.',
      'هذه النقلة كانت حاسمة لاستمرار أفضليتك.',
    ],
    'best': [
      'طابقت اختيار المحرك تمامًا.',
      'لا توجد نقلة أقوى منها في هذه الوضعية.',
    ],
    'excellent': [
      'حافظت على موقفك دون أي خسارة تُذكر.',
      'الفرق بينها وبين الأفضل لا يكاد يُذكر.',
    ],
    'good': [
      'لم تُضعف موقفك، وإن وُجد خيار أدق.',
      'نقلة منطقية تحافظ على توازن الوضعية.',
    ],
    'inaccuracy': [
      'سمحت للخصم بتحسين موقفه قليلًا.',
      'فرّطت في جزء بسيط من أفضليتك.',
    ],
    'mistake': [
      'منحت الخصم أفضلية واضحة.',
      'تغيّر ميزان الوضعية بشكل ملحوظ بعد هذه النقلة.',
    ],
    'miss': [
      'كان لديك استمرار أقوى بكثير فلم تستغله.',
      'ضاعت فرصة كانت ستُحسّن موقفك كثيرًا.',
    ],
    'blunder': [
      'سمحت للخصم بميزة كبيرة، وغالبًا هناك تهديد لم تنتبه له.',
      'هذه النقلة قلبت الوضعية لصالح الخصم.',
    ],
  };

  static const Map<String, List<String>> _whyEn = {
    'brilliant': [
      'It is hard to find and keeps your position strong.',
      'It often carries a deep tactical idea or a sound sacrifice.',
    ],
    'great': [
      'You found almost the only move that keeps your position.',
      'This move was decisive for keeping your advantage.',
    ],
    'best': [
      'It matched the engine’s top choice exactly.',
      'No move is stronger in this position.',
    ],
    'excellent': [
      'You kept your position with no real loss.',
      'The gap to the best move is negligible.',
    ],
    'good': [
      'It did not weaken your position, though a sharper option existed.',
      'A logical move that keeps the position balanced.',
    ],
    'inaccuracy': [
      'It let your opponent improve slightly.',
      'You gave up a small part of your advantage.',
    ],
    'mistake': [
      'It gave your opponent a clear advantage.',
      'The balance of the position shifted noticeably.',
    ],
    'miss': [
      'A much stronger continuation was available.',
      'You let slip a chance that would have improved things a lot.',
    ],
    'blunder': [
      'It handed your opponent a big edge, often via a threat you missed.',
      'This move flipped the position in your opponent’s favour.',
    ],
  };

  static const Map<String, List<String>> _phaseAr = {
    'opening': [
      'في الافتتاح: طوّر قطعك، سيطر على المركز، وأمّن ملكك.',
      'تذكّر: لا تحرّك القطعة نفسها مرتين في الافتتاح بلا سبب.',
      'حاول أن تُبيّت مبكرًا وتربط الرخين.',
      'السيطرة على المركز (e4 وd4 وe5 وd5) تمنحك مساحة أكبر.',
    ],
    'middlegame': [
      'في الوسط: ابحث عن تهديدات الخصم قبل أي نقلة هجومية، وحسّن أضعف قطعك.',
      'قبل أن تهاجم، تأكد أن قطعك محمية.',
      'ابحث عن الكشوف والأخذات والتهديدات قبل كل نقلة.',
      'انقل قطعك إلى خانات نشطة واربط بينها.',
    ],
    'endgame': [
      'في النهاية: نشّط ملكك وابحث عن بيدق حر.',
      'في النهايات الملك قطعة هجومية؛ اقترب به من المركز.',
      'احسب سباق البيادق بدقة — كل نقلة تُحسب.',
      'ضع الرخ خلف البيدق الحر لتعزيزه.',
    ],
  };

  static const Map<String, List<String>> _phaseEn = {
    'opening': [
      'Opening: develop your pieces, fight for the center, castle.',
      'Remember: do not move the same piece twice in the opening without '
          'reason.',
      'Try to castle early and connect your rooks.',
      'Controlling the center (e4, d4, e5, d5) gives you more space.',
    ],
    'middlegame': [
      'Middlegame: check your opponent’s threats before attacking, and '
          'improve your worst piece.',
      'Before attacking, make sure your pieces are protected.',
      'Look for checks, captures and threats before every move.',
      'Place your pieces on active squares and coordinate them.',
    ],
    'endgame': [
      'Endgame: activate your king and look for a passed pawn.',
      'In endgames the king is an attacking piece; bring it to the center.',
      'Calculate the pawn race precisely — every move counts.',
      'Put the rook behind the passed pawn to support it.',
    ],
  };

  static const Map<String, List<String>> _lessonAr = {
    'brilliant': [
      'الصبر في الحساب يُكافأ؛ واصل البحث عن الأفكار الإجبارية.',
      'التضحية المدروسة تبدأ دائمًا بحساب دقيق للردود.',
      'استمر في البحث عن النقلات التي لا يتوقعها الخصم.',
    ],
    'great': [
      'ابحث دائمًا عن النقلة التي تفرض على الخصم الرد.',
      'في اللحظات الحرجة، قارن كل الردود قبل أن تلعب.',
      'التركيز في المواقف الحاسمة هو سر الفوز.',
    ],
    'best': [
      'استمر بنفس المنهج: تحقق من التهديدات ثم اختر.',
      'سؤال «ماذا يهدد الخصم؟» قبل كل نقلة يصنع الفرق.',
      'ثبات جودة نقلاتك يبني الفوز تدريجيًا.',
    ],
    'excellent': [
      'جودة نقلاتك ثابتة، استمر.',
      'أنت قريب جدًا من لعب المحرك؛ واصل.',
      'حافظ على هذا التركيز في بقية المباراة.',
    ],
    'good': [
      'قبل أن تلعب، قارن بين نقلتين على الأقل.',
      'جيد، لكن ابحث دائمًا عن النقلة التي تزيد الضغط.',
      'حاول أن تسأل: هل توجد نقلة تُحسّن أضعف قطعة عندي؟',
    ],
    'inaccuracy': [
      'قبل النقلة الأخيرة، اسأل: هل يمكنني زيادة الضغط أولًا؟',
      'الأخطاء الصغيرة تتراكم؛ اقضِ دقيقة إضافية في المواقف المتوازنة.',
      'قارن نقلتك بخيار آخر قبل أن تلعبها.',
    ],
    'mistake': [
      'قبل أن تنفذ النقلة، تحقق من كل رد ممكن للخصم يضع قطعة.',
      'اسأل نفسك: ماذا سيلعب الخصم بعد نقلتي مباشرة؟',
      'تحقق من القطع غير المحمية قبل أن تلعب.',
    ],
    'miss': [
      'عندما يكون موقفك جيدًا، ابحث عن الكشوف والمكاسب أولًا.',
      'قبل الاسترخاء، افحص هل توجد ضربة تكتيكية متاحة.',
      'الأفضلية تُحوَّل إلى فوز بالبحث عن الاستمرار الأقوى.',
    ],
    'blunder': [
      'اجعل فحص الأمان عادة: هل قطعتي محمية؟ ما تهديد الخصم؟',
      'خذ نفسًا وراجع الوضعية قبل كل نقلة في اللحظات الحرجة.',
      'الخطأ الفادح غالبًا تهديد بسيط لم يُلاحَظ؛ افحص الكشوف والأخذات.',
    ],
  };

  static const Map<String, List<String>> _lessonEn = {
    'brilliant': [
      'Patient calculation pays off; keep seeking forcing ideas.',
      'A sound sacrifice always starts with precise calculation.',
      'Keep looking for moves your opponent will not expect.',
    ],
    'great': [
      'Always look for the move that forces a reply.',
      'In critical moments, compare every reply before moving.',
      'Focus in decisive positions is the key to winning.',
    ],
    'best': [
      'Keep the same routine: check threats, then choose.',
      'Asking “what is my opponent threatening?” makes the difference.',
      'Steady move quality builds wins gradually.',
    ],
    'excellent': [
      'Your move quality is steady, keep going.',
      'You are very close to engine play; keep it up.',
      'Keep this focus for the rest of the game.',
    ],
    'good': [
      'Before moving, compare at least two candidate moves.',
      'Good, but always look for the move that adds pressure.',
      'Ask yourself: is there a move that improves my worst piece?',
    ],
    'inaccuracy': [
      'Before the final move, ask: can I add pressure first?',
      'Small errors add up; spend an extra minute in balanced positions.',
      'Compare your move with another option before playing it.',
    ],
    'mistake': [
      'Before moving, check every reply that attacks a piece.',
      'Ask yourself: what will my opponent play right after my move?',
      'Check for unprotected pieces before you play.',
    ],
    'miss': [
      'When you are better, look for checks and captures first.',
      'Before relaxing, check whether a tactical shot is available.',
      'Advantage is converted by finding the strongest continuation.',
    ],
    'blunder': [
      'Make a safety check a habit: is my piece protected?',
      'Take a breath and re-read the position before every critical move.',
      'A blunder is often a simple threat that went unnoticed; check '
          'checks and captures.',
    ],
  };

  static const List<String> _genericAr = [
    'يبدو أنك لم تلاحظ تهديدًا أو فكرة للخصم.',
    'قارن بين نقلتين على الأقل قبل أن تقرر.',
    'ربما كانت هناك قطعة ضعيفة تحتاج إلى حماية أو تحسين.',
    'تحقق دائمًا من ردّ الخصم الأقوى قبل أن تلعب.',
  ];

  static const List<String> _genericEn = [
    'It seems you missed a threat or an idea from your opponent.',
    'Compare at least two moves before deciding.',
    'Perhaps a weak piece needed protection or improvement.',
    'Always check your opponent’s strongest reply before moving.',
  ];

  static const List<String> _posLessonAr = [
    'قبل أن تنفذ نقلتك، اسأل: ما تهديد الخصم؟',
    'ابحث عن القطعة الأضعف عندك وحسّنها.',
    'قارن بين الخطط قبل أن تختار نقلة واحدة.',
  ];

  static const List<String> _posLessonEn = [
    'Before moving, ask: what is my opponent threatening?',
    'Find your weakest piece and improve it.',
    'Compare plans before choosing a single move.',
  ];
}
