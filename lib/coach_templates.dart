import 'coach_models.dart';
import 'game_review_models.dart';

/// محرك القوالب: يعمل دائمًا (بدون نموذج) كـ Fallback وللنقلات
/// السهلة (best / excellent / good). يراعي اللغة ومستوى اللاعب.
class CoachTemplateEngine {
  CoachTemplateEngine._();

  // ---------------- النقلة ----------------

  static CoachExplanation explainMove(
    CoachMoveInput i, {
    required CoachLevel level,
    required CoachLang lang,
    bool revealBest = false,
    String? personalNote,
  }) {
    final ar = lang == CoachLang.ar;
    final q = i.quality;
    final t = (ar ? _ar : _en)[_group(q)]!;

    final detailed =
        level == CoachLevel.advanced || level == CoachLevel.expert;

    final isErr = _isError(q);

    final buf = StringBuffer();

    buf.write(ar ? 'لعبت ${i.san}. ' : 'You played ${i.san}. ');
    buf.write(t.why);

    if (isErr && i.evalLoss > 0.05) {
      final loss = i.evalLoss.toStringAsFixed(1);

      if (detailed) {
        buf.write(
          ar
              ? ' الخسارة التقديرية: $loss بيدق '
                  '(${_fmt(i.evalBefore)} ← ${_fmt(i.evalAfter)}).'
              : ' Estimated loss: $loss pawns '
                  '(${_fmt(i.evalBefore)} → ${_fmt(i.evalAfter)}).',
        );
      } else if (level == CoachLevel.intermediate) {
        buf.write(
          ar
              ? ' كلّفتك هذه النقلة نحو $loss بيدق من أفضليتك.'
              : ' This move cost you about $loss pawns of advantage.',
        );
      }
    }

    final verdict = _tablebase(i.tablebaseVerdict, ar);

    if (verdict != null) buf.write(' $verdict');

    String? better;

    if (revealBest && isErr && i.bestMove.isNotEmpty) {
      better = i.bestMove;

      buf.write(
        ar
            ? ' كانت ${i.bestMove} أقوى في هذه الوضعية.'
            : ' ${i.bestMove} was stronger in this position.',
      );

      if (detailed && i.principalVariation.length > 1) {
        buf.write(
          ar
              ? ' الخط الرئيسي: ${i.principalVariation.join(' ')}.'
              : ' Main line: ${i.principalVariation.join(' ')}.',
        );
      }
    }

    final idea = (ar ? _phaseAr : _phaseEn)[_phase(i.phase)]!;

    var lesson = (ar ? _lessonAr : _lessonEn)[_group(q)]!;

    if (personalNote != null && personalNote.isNotEmpty) {
      lesson = '$lesson\n🎓 $personalNote';
    }

    return CoachExplanation(
      title: t.title,
      summary: t.summary,
      explanation: buf.toString(),
      betterMove: better,
      idea: idea,
      lesson: lesson,
    );
  }

  // ---------------- الوضعية ----------------

  static CoachExplanation explainPosition(
    CoachPositionInput p, {
    required CoachLevel level,
    required CoachLang lang,
  }) {
    final ar = lang == CoachLang.ar;

    final who = p.sideToMove == 'white'
        ? (ar ? 'الأبيض' : 'White')
        : (ar ? 'الأسود' : 'Black');

    final e = p.evalPawns;

    String state;

    if (e.abs() < 0.3) {
      state = ar ? 'الوضعية متوازنة تقريبًا.' : 'The position is roughly equal.';
    } else {
      final lead = e > 0 ? (ar ? 'الأبيض' : 'White') : (ar ? 'الأسود' : 'Black');

      state = ar
          ? 'الأفضلية لدى $lead (${_fmt(e)}).'
          : '$lead is better (${_fmt(e)}).';
    }

    final idea = (ar ? _phaseAr : _phaseEn)[_phase(p.phase)]!;

    final line = p.principalVariation.take(4).join(' ');

    return CoachExplanation(
      title: ar ? '🎓 تحليل الوضعية' : '🎓 Position analysis',
      summary: state,
      explanation: ar
          ? 'الدور على $who. أفضل نقلة حسب المحرك: ${p.bestMove}'
              '${line.isEmpty ? '' : ' (الخط: $line)'}.'
          : '$who to move. Engine best move: ${p.bestMove}'
              '${line.isEmpty ? '' : ' (line: $line)'}.',
      betterMove: p.bestMove,
      idea: idea,
      lesson: ar
          ? 'قبل أن تنفذ نقلتك، اسأل: ما تهديد الخصم؟'
          : 'Before moving, ask: what is my opponent threatening?',
    );
  }

  // ---------------- المباراة ----------------

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
    }

    final acpl = moves.isEmpty ? 0 : (loss * 100 / moves.length).round();

    final summary = ar
        ? 'لعبت ${moves.length} نقلة: $best ممتازة، $inacc غير دقيقة، '
            '$mistakes أخطاء، $blunders أخطاء فادحة.'
        : 'You played ${moves.length} moves: $best strong, $inacc '
            'inaccurate, $mistakes mistakes, $blunders blunders.';

    final detailed =
        level == CoachLevel.advanced || level == CoachLevel.expert;

    final explanation = detailed
        ? (ar
            ? 'متوسط خسارة النقلة (ACPL): $acpl سنتيبون.'
                '${brilliant > 0 ? ' نقلات Brilliant: $brilliant.' : ''}'
            : 'Average centipawn loss (ACPL): $acpl.'
                '${brilliant > 0 ? ' Brilliant moves: $brilliant.' : ''}')
        : (blunders + mistakes == 0
            ? (ar ? 'لعبة نظيفة، أحسنت!' : 'A clean game, well done!')
            : (ar
                ? 'ركّز على تقليل الأخطاء الكبيرة أولًا.'
                : 'Focus on reducing the big mistakes first.'));

    return CoachExplanation(
      title: ar ? '🎓 ملخص المباراة' : '🎓 Game summary',
      summary: summary,
      explanation: explanation,
      lesson: personalNote?.isNotEmpty == true
          ? personalNote!
          : (ar
              ? 'راجع أخطاءك الفادحة أولًا؛ فيها أكبر مكسب.'
              : 'Review your blunders first; that is where the gain is.'),
    );
  }

  // ---------------- مساعدات ----------------

  static String _fmt(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}';

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

  static const Map<String, _T> _ar = {
    'brilliant': _T('✨ نقلة رائعة', 'وجدت نقلة استثنائية!',
        'هذه نقلة يصعب العثور عليها وتحافظ على موقفك بقوة.'),
    'great': _T('🟢 نقلة قوية جدًا', 'نقلة حاسمة في الوضعية.',
        'وجدت النقلة التي تتطلبها الوضعية.'),
    'best': _T('🟢 أفضل نقلة', 'هذه أفضل نقلة في الوضعية.',
        'طابقت اختيار المحرك تمامًا.'),
    'excellent': _T('🟢 نقلة ممتازة', 'نقلة قريبة جدًا من الأفضل.',
        'حافظت على موقفك دون أي خسارة تُذكر.'),
    'good': _T('🟢 نقلة جيدة', 'نقلة مقبولة وآمنة.',
        'لم تُضعف موقفك، وإن وُجد خيار أدق.'),
    'inaccuracy': _T('🟡 نقلة غير دقيقة', 'النقلة جيدة لكن هناك أدق منها.',
        'سمحت للخصم بتحسين موقفه قليلًا.'),
    'mistake': _T('🟠 خطأ', 'هذه النقلة أضعفت موقفك.',
        'منحت الخصم أفضلية واضحة.'),
    'miss': _T('🟠 فرصة ضائعة', 'فاتتك فرصة قوية.',
        'كان لديك استمرار أقوى بكثير فلم تستغله.'),
    'blunder': _T('🔴 خطأ فادح', 'هذه النقلة غيّرت مسار المباراة.',
        'سمحت للخصم بميزة كبيرة، وغالبًا هناك تهديد لم تنتبه له.'),
  };

  static const Map<String, _T> _en = {
    'brilliant': _T('✨ Brilliant move', 'You found an exceptional move!',
        'A hard-to-find move that keeps your position strong.'),
    'great': _T('🟢 Great move', 'A critical move in the position.',
        'You found what the position demanded.'),
    'best': _T('🟢 Best move', 'This is the best move here.',
        'It matches the engine’s top choice.'),
    'excellent': _T('🟢 Excellent', 'Very close to the best move.',
        'You kept your position with no real loss.'),
    'good': _T('🟢 Good move', 'A solid, safe move.',
        'It did not weaken your position, though a sharper option existed.'),
    'inaccuracy': _T('🟡 Inaccuracy', 'Good, but there was a sharper move.',
        'It let your opponent improve slightly.'),
    'mistake': _T('🟠 Mistake', 'This move weakened your position.',
        'It gave your opponent a clear advantage.'),
    'miss': _T('🟠 Missed opportunity', 'You missed a strong chance.',
        'A much stronger continuation was available.'),
    'blunder': _T('🔴 Blunder', 'This move changed the course of the game.',
        'It handed your opponent a big edge, often via a threat you missed.'),
  };

  static const Map<String, String> _phaseAr = {
    'opening': 'في الافتتاح: طوّر قطعك، سيطر على المركز، وأمّن ملكك.',
    'middlegame':
        'في الوسط: ابحث عن تهديدات الخصم قبل أي نقلة هجومية، وحسّن أضعف قطعك.',
    'endgame': 'في النهاية: نشّط ملكك وابحث عن بيدق حر.',
  };

  static const Map<String, String> _phaseEn = {
    'opening': 'Opening: develop your pieces, fight for the center, castle.',
    'middlegame':
        'Middlegame: check your opponent’s threats before attacking, and improve your worst piece.',
    'endgame': 'Endgame: activate your king and look for a passed pawn.',
  };

  static const Map<String, String> _lessonAr = {
    'brilliant': 'الصبر في الحساب يُكافأ؛ واصل البحث عن الأفكار الإجبارية.',
    'great': 'ابحث دائمًا عن النقلة التي تفرض على الخصم الرد.',
    'best': 'استمر بنفس المنهج: تحقق من التهديدات ثم اختر.',
    'excellent': 'جودة نقلاتك ثابتة، استمر.',
    'good': 'قبل أن تلعب، قارن بين نقلتين على الأقل.',
    'inaccuracy': 'قبل النقلة الأخيرة، اسأل: هل يمكنني زيادة الضغط أولًا؟',
    'mistake': 'قبل أن تنفذ النقلة، تحقق من كل رد ممكن للخصم يضع قطعة.',
    'miss': 'عندما يكون موقفك جيدًا، ابحث عن الكشوف والمكاسب أولًا.',
    'blunder': 'اجعل فحص الأمان عادة: هل قطعتي محمية؟ ما تهديد الخصم؟',
  };

  static const Map<String, String> _lessonEn = {
    'brilliant': 'Patient calculation pays off; keep seeking forcing ideas.',
    'great': 'Always look for the move that forces a reply.',
    'best': 'Keep the same routine: check threats, then choose.',
    'excellent': 'Your move quality is steady, keep going.',
    'good': 'Before moving, compare at least two candidate moves.',
    'inaccuracy': 'Before the final move, ask: can I add pressure first?',
    'mistake': 'Before moving, check every reply that attacks a piece.',
    'miss': 'When you are better, look for checks and captures first.',
    'blunder': 'Make a safety check a habit: is my piece protected?',
  };
}

class _T {
  final String title;
  final String summary;
  final String why;

  const _T(this.title, this.summary, this.why);
}
