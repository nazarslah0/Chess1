part of 'game_analysis_screen.dart';

/// حسابات وإحصاءات المباراة (الدقة، الجودة، اللحظات الحرجة...) — بلا واجهة.
extension _AnalysisStats on _GameAnalysisScreenState {
  /// دقة كل نقلة ووزنها (تقلّب الوضعية) للنقلات المحلَّلة فعليًا.
  MoveAccuracyData get _accData {
    final m = _qualities.length;

    if (m == 0 || _evalPawns.length < m + 1) {
      return const MoveAccuracyData(
        accuracy: <double>[],
        weight: <double>[],
      );
    }

    return computeMoveAccuracyData(
      cpWhite: [
        for (var i = 0; i <= m; i++)
          _cpAt(i),
      ],
      sides: [
        for (var i = 0; i < m; i++) _plies[i].color,
      ],
    );
  }

  /// دقة المباراة لكل لاعب بالطريقة الصارمة (متوسط مرجَّح +
  /// متوافق) — انظر computeMoveAccuracyData في game_review_models.
  Map<String, double> get _accuracyBySide {
    if (_qualities.isEmpty) {
      return {'w': 0, 'b': 0};
    }

    final data = _accData;

    return {
      'w': combineAccuracy(data, [
        for (var i = 0; i < _qualities.length; i++)
          if (_plies[i].color == 'w') i,
      ]),
      'b': combineAccuracy(data, [
        for (var i = 0; i < _qualities.length; i++)
          if (_plies[i].color == 'b') i,
      ]),
    };
  }

  /// Average Centipawn Loss لكل لاعب — متوسط خسارة التقييم
  /// الفعلية بوحدة القرن لكل نقلة لعبها، محسوبة من نتائج
  /// Stockfish المخزَّنة مباشرة (وليست مُخترَعة). قيمة أقل
  /// = لعب أدق. null يعني عدم توفر بيانات كافية بعد.
  Map<String, double?> get _acplBySide {
    final results = _c.results;

    if (results.isEmpty) {
      return {'w': null, 'b': null};
    }

    // الحساب في analysis_rules.dart: من منظور اللاعب الذي نفّذ النقلة،
    // مع تقييد التقييم ±1000 قرن كي لا يفسد المات المتوسط.
    final acpl = computeAcpl(results);

    return {
      'w': acpl.white == null ? null : acpl.white! / 100,
      'b': acpl.black == null ? null : acpl.black! / 100,
    };
  }

  /// متوسط الدقة لكل لاعب في كل مرحلة من مراحل اللعبة.
  Map<String, Map<String, double>> get _accuracyByPhase {
    final sums = {
      'opening': {'w': 0.0, 'b': 0.0},
      'middlegame': {'w': 0.0, 'b': 0.0},
      'endgame': {'w': 0.0, 'b': 0.0},
    };

    final counts = {
      'opening': {'w': 0, 'b': 0},
      'middlegame': {'w': 0, 'b': 0},
      'endgame': {'w': 0, 'b': 0},
    };

    for (var i = 0; i < _qualities.length; i++) {
      final phase = _phaseOf(i);
      final color = _plies[i].color;
      final acc = _accuracyAt(i);

      sums[phase]![color] =
          (sums[phase]![color] ?? 0) + acc;
      counts[phase]![color] =
          (counts[phase]![color] ?? 0) + 1;
    }

    final result = <String, Map<String, double>>{};

    for (final phase in sums.keys) {
      result[phase] = {
        for (final color in ['w', 'b'])
          color: (counts[phase]![color] ?? 0) > 0
              ? sums[phase]![color]! /
                  counts[phase]![color]!
              : 0,
      };
    }

    return result;
  }

  Map<MoveQuality, int> get _qualityCounts {
    final counts = <MoveQuality, int>{};

    for (final q in _qualities) {
      counts[q] = (counts[q] ?? 0) + 1;
    }

    return counts;
  }

  /// نفس العدّ لكن مقسّم لكل لاعب — مطلوب لقسم "إحصائيات
  /// الأبيض والأسود" في تقرير المباراة.
  Map<String, Map<MoveQuality, int>> get _qualityCountsBySide {
    final result = {
      'w': <MoveQuality, int>{},
      'b': <MoveQuality, int>{},
    };

    for (var i = 0; i < _qualities.length; i++) {
      final color = _plies[i].color;
      final q = _qualities[i];
      result[color]![q] = (result[color]![q] ?? 0) + 1;
    }

    return result;
  }

  /// نقلة "رائعة!!" الأبرز في المباراة (أكبر قيمة تضحية)، أو
  /// null إن لم توجد أي نقلة رائعة — لا نخترع "أفضل نقلة"
  /// بديلة بلا معيار حقيقي يميّزها عن عشرات النقلات "الأفضل".
  /// نقلة "رائعة!!" الأبرز في المباراة، منفصلة تمامًا عن
  /// "أفضل نقلة Engine" — قد توجد إحداهما بدون الأخرى.
  int? get _brilliantMoveIndex {
    int? best;
    var bestScore = -1;

    for (var i = 0; i < _qualities.length; i++) {
      if (_qualities[i] != MoveQuality.brilliant) continue;

      try {
        final boardBefore = GameState.parseBoard(
          _plies[i].fenBefore.split(' ').first,
        );

        final movingPiece =
            boardBefore[_plies[i].from];

        final movingValue = movingPiece != null &&
                movingPiece.length == 2
            ? (pieceValues[movingPiece[1]] ?? 0)
            : 0;

        if (movingValue > bestScore) {
          bestScore = movingValue;
          best = i;
        }
      } catch (_) {}
    }

    return best;
  }

  /// "أفضل نقلة في المباراة" (Best Engine Move) — معيار
  /// مختلف تمامًا عن Brilliant: من بين كل النقلات التي
  /// طابقت bestUci الخاص بـ Stockfish تمامًا (from/to/
  /// promotion)، نختار الوضعية التي كان فيها الفارق عن ثاني
  /// أفضل نقلة أكبر ما يمكن — أي الموضع الذي كان فيه إيجاد
  /// هذه النقلة بالذات الأكثر أهمية وحسمًا، بدل اختيار
  /// عشوائي من بين عشرات النقلات "الأفضل" في مباراة جيدة.
  int? get _bestEngineMoveIndex {
    int? best;
    var bestGap = -1 << 30;

    for (var i = 0; i < _isBestEngineMove.length; i++) {
      if (!_isBestEngineMove[i]) continue;

      final gap = _moveGapCp[i];

      if (gap != null && gap > bestGap) {
        bestGap = gap;
        best = i;
      }
    }

    return best;
  }

  /// أسوأ نقلة في المباراة = أكبر خسارة تقييم مُسجَّلة فعليًا.
  int? get _worstMoveIndex {
    if (_qualities.isEmpty) return null;

    int? worst;
    var worstLoss = -1 << 30;

    for (var i = 0; i < _qualities.length; i++) {
      final loss = _lossAt(i);

      if (loss > worstLoss) {
        worstLoss = loss;
        worst = i;
      }
    }

    return worstLoss > 0 ? worst : null;
  }

  /// الفرص الضائعة: فقط النقلات المصنّفة فعليًا miss بناءً على
  /// معيار محسوب (انهيار أفضلية حاسمة)، وليس تخمينًا.
  List<int> get _missedOpportunityIndices {
    final result = <int>[];

    for (var i = 0; i < _qualities.length; i++) {
      if (_qualities[i] == MoveQuality.miss) {
        result.add(i);
      }
    }

    return result;
  }

  /// نص ملخّص المباراة — مبني بالكامل من أرقام محسوبة فعليًا
  /// (قالب نصي، وليس توليدًا بالذكاء الاصطناعي).
  String get _gameSummaryText {
    if (_qualities.isEmpty) return '';

    final acc = _accuracyBySide;
    final worst = _worstMoveIndex;

    final parts = <String>[];

    parts.add(
      'دقة $_whiteName ${(acc['w'] ?? 0).toStringAsFixed(0)}%'
      ' مقابل دقة $_blackName'
      ' ${(acc['b'] ?? 0).toStringAsFixed(0)}%.',
    );

    if (worst != null) {
      final ply = _plies[worst];
      final moveNumber = (worst ~/ 2) + 1;
      final mover =
          ply.color == 'w' ? _whiteName : _blackName;
      final lossPawns =
          (_lossAt(worst) / 100).toStringAsFixed(1);

      parts.add(
        'أكبر خطأ في المباراة كان من $mover عند النقلة'
        ' $moveNumber'
        '${ply.color == 'w' ? '.' : '...'} '
        '${ply.san}${_sanSuffix(_qualities[worst])}'
        ' (خسارة تقييم $lossPawns بيدق تقريبًا).',
      );
    }

    final missed = _missedOpportunityIndices;

    if (missed.isNotEmpty) {
      parts.add(
        'هناك ${missed.length} فرصة/فرص لم تُستغل بالكامل'
        ' خلال المباراة.',
      );
    }

    return parts.join(' ');
  }

  /// أكبر اللحظات الحرجة (أخطاء/فرص ضائعة) مرتبة تنازليًا حسب
  /// حجم خسارة التقييم.
  List<_CriticalMoment> get _criticalMoments {
    final moments = <_CriticalMoment>[
      for (final m in _c.results)
        if (m.isCritical)
          _CriticalMoment(
            plyIndex: m.ply,
            quality: m.classification,
            lossCp: m.evaluationLossCp.clamp(0, 1000),
            score: m.criticalScore,
            kind: m.criticalKind ?? 'swing',
          ),
    ];

    moments.sort((a, b) => b.score.compareTo(a.score));

    return moments;
  }
}
