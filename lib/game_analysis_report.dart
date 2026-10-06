part of 'game_analysis_screen.dart';

/// تبويبات الملخص والتقرير (الدقة، المراحل، اللاعبون).
extension _AnalysisReportTabs on _GameAnalysisScreenState {
  Widget _buildSummaryTab() {
    if (_analyzing || _qualities.isEmpty) {
      return Center(
        child: Text(
          _analyzing
              ? 'جارٍ تحليل المباراة...'
              : 'لا توجد نتائج تحليل بعد.',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildAccuracySummary(),
        const SizedBox(height: 12),
        _buildPerformanceCard(),
        if (_maiaPerformance('w') != null ||
            _maiaPerformance('b') != null)
          const SizedBox(height: 12),
        _buildPhaseSummary(),
      ],
    );
  }

  // ------------------------------------------------------------
  // تبويب: نظرة عامة
  // ------------------------------------------------------------

  Widget _buildCurrentMoveInfo() {
    if (_currentIndex == 0) {
      final pv = _pvUci.isNotEmpty
          ? pvToSan(_fens[0], _pvUci[0])
          : '';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'الوضعية الابتدائية',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (pv.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'الخط المقترح: $pv',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final k = _currentIndex - 1;

    if (k >= _qualities.length || k >= _plies.length) {
      return const SizedBox();
    }

    final ply = _plies[k];
    final q = _qualities[k];
    final info = moveQualityInfo[q]!;
    final loss = _lossAt(k);
    final moveNumber = (k ~/ 2) + 1;

    final bestUci = k < _bestUci.length
        ? _bestUci[k]
        : '';

    final bestSan = parseUci(bestUci) != null
        ? pvToSan(_fens[k], [bestUci])
        : '';

    final pv = k < _pvUci.length
        ? pvToSan(_fens[k], _pvUci[k])
        : '';

    final isBestOrBrilliant =
        (k < _isBestEngineMove.length && _isBestEngineMove[k]) ||
        q == MoveQuality.best ||
        q == MoveQuality.brilliant ||
        q == MoveQuality.great ||
        q == MoveQuality.book;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: info.color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'النقلة الحالية:  $moveNumber'
            '${ply.color == 'w' ? '.' : '...'} '
            '${ply.san}${_sanSuffix(q)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                info.icon,
                size: 16,
                color: info.color,
              ),
              const SizedBox(width: 4),
              Text(
                info.label,
                style: TextStyle(
                  color: info.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'خسارة تقييم: '
                '${(loss / 100).toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (_bookNoteAt(k) != null) ...[
            const SizedBox(height: 6),
            Text(
              _bookNoteAt(k)!,
              style: TextStyle(
                color: moveQualityInfo[MoveQuality.book]!.color,
                fontSize: 12,
              ),
            ),
          ],
          if (_maiaNoteAt(k) != null) ...[
            const SizedBox(height: 6),
            Text(
              _maiaNoteAt(k)!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
          if (_tbNoteAt(k) != null) ...[
            const SizedBox(height: 6),
            Text(
              _tbNoteAt(k)!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
          if (!isBestOrBrilliant &&
              bestSan.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'أفضل نقلة: $bestSan',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (pv.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'الخط الرئيسي: $pv',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccuracySummary() {
    final acc = this._accuracyBySide;
    final acpl = this._acplBySide;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceAround,
            children: [
              _accuracyChip(
                _whiteName,
                acc['w'] ?? 0,
                acpl['w'],
              ),
              _accuracyChip(
                _blackName,
                acc['b'] ?? 0,
                acpl['b'],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'دقة Chess2 — مقياس خاص بالتطبيق، ليس مطابقًا'
            ' لدقة Chess.com',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accuracyChip(
    String label,
    double acc,
    double? acpl,
  ) {
    return Column(
      children: [
        Text(
          '${acc.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'دقة Chess2 — $label',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'ACPL: ${acpl == null ? 'N/A' : acpl.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseSummary() {
    final byPhase = this._accuracyByPhase;

    Widget row(String label, String key) {
      final w = byPhase[key]!['w']!;
      final b = byPhase[key]!['b']!;

      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 4,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label),
            ),
            Expanded(
              child: Text(
                '$_whiteName ${w.toStringAsFixed(0)}%'
                '   •   '
                '$_blackName ${b.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'مراحل المباراة',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          row('الافتتاح', 'opening'),
          row('وسط اللعبة', 'middlegame'),
          row('النهايات', 'endgame'),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // تبويب: تقرير المباراة
  // ------------------------------------------------------------
  //
  // ملاحظة تصميم مهمة: هذا تبويب ضمن نفس شاشة GameAnalysisScreen
  // (وليس شاشة منفصلة يُنتقل إليها عبر Navigator) عن قصد — لأن
  // فتح شاشة GameAnalysisScreen جديدة يعني إعادة تحليل المباراة
  // بالكامل عبر Stockfish من جديد (initState يبدأ التحليل مباشرة).
  // بما أن التبويب يشارك نفس الـ State الذي يحمل نتائج التحليل
  // المحفوظة أصلًا، فإن "الانتقال إلى النقلة" من التقرير لا يحتاج
  // أكثر من تبديل التبويب + تحديث _currentIndex — بلا أي تحليل
  // إضافي، تمامًا كما يتطلب القسم 14 من الطلب.

  Map<String, _PhaseStat> get _phaseStatsFull {
    final result = <String, _PhaseStat>{};

    for (final phase in [
      'opening',
      'middlegame',
      'endgame',
    ]) {
      var moveCount = 0;
      var errorCount = 0;
      final phaseIdx = <int>[];
      final accData = this._accData;

      for (var i = 0; i < _qualities.length; i++) {
        if (_phaseOf(i) != phase) continue;

        moveCount++;
        phaseIdx.add(i);

        final q = _qualities[i];

        if (q == MoveQuality.mistake ||
            q == MoveQuality.blunder ||
            q == MoveQuality.miss) {
          errorCount++;
        }
      }

      result[phase] = _PhaseStat(
        moveCount: moveCount,
        accuracy: moveCount > 0
            ? combineAccuracy(accData, phaseIdx)
            : 0,
        errorCount: errorCount,
      );
    }

    return result;
  }

  Widget _buildReportTab() {
    if (_analyzing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'التقرير يظهر بعد اكتمال تحليل المباراة...\n'
            '${(_progress * 100).round()}%',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_plies.isEmpty) {
      return const Center(
        child: Text('لا توجد بيانات كافية للتقرير.'),
      );
    }

    final acc = this._accuracyBySide;
    final acplBySide = this._acplBySide;
    final countsBySide = this._qualityCountsBySide;
    final bestEngineIdx = this._bestEngineMoveIndex;
    final brilliantIdx = this._brilliantMoveIndex;
    final worstIdx = this._worstMoveIndex;
    final missed = this._missedOpportunityIndices;
    final opening = _headers['Opening'];
    final eco = _headers['ECO'];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // --------------------------------------------------
        // معلومات المباراة
        // --------------------------------------------------
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'تقرير المباراة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('الأبيض: $_whiteName'),
              Text('الأسود: $_blackName'),
              if (_resultText.isNotEmpty)
                Text('النتيجة: $_resultText'),
              Text('عدد النقلات: ${_plies.length}'),
              if (opening != null)
                Text('الافتتاح: $opening'
                    '${eco != null ? ' ($eco)' : ''}')
              else if (eco != null)
                Text('رمز الافتتاح (ECO): $eco'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --------------------------------------------------
        // ملخص المباراة
        // --------------------------------------------------
        if (this._gameSummaryText.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.06),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملخص المباراة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(this._gameSummaryText),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // --------------------------------------------------
        // إحصائيات الأبيض والأسود
        // --------------------------------------------------
        const Text(
          'إحصائيات اللاعبين',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _playerStatsCard(
                _whiteName,
                acc['w'] ?? 0,
                acplBySide['w'],
                countsBySide['w']!,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _playerStatsCard(
                _blackName,
                acc['b'] ?? 0,
                acplBySide['b'],
                countsBySide['b']!,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // --------------------------------------------------
        // الرسم البياني للتقييم
        // --------------------------------------------------
        const Text(
          'تقييم المباراة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _EvalGraph(
          evalPawns: _evalPawns,
          qualities: _qualities,
          moves: _c.results,
          currentIndex: _currentIndex,
          onSelect: (i) => _jumpAndShowBoard(i),
        ),
        const SizedBox(height: 8),
        _buildGraphMoveInfo(),
        const SizedBox(height: 16),

        // --------------------------------------------------
        // أفضل نقلة (Best Engine Move) وأسوأ نقلة
        // --------------------------------------------------
        // ملاحظة: "أفضل نقلة" هنا تعني النقلة المطابقة فعليًا
        // لـ bestUci الخاص بـ Stockfish — وليست بالضرورة
        // النقلة المصنّفة "رائعة!!" (Brilliant قسم منفصل
        // تمامًا تحته، يظهر فقط إن وُجد فعلًا).
        Row(
          children: [
            Expanded(
              child: _bestWorstCard(
                title: 'أفضل نقلة',
                icon: Icons.star_rounded,
                color: const Color(0xFF2AA876),
                plyIndex: bestEngineIdx,
                emptyText:
                    'لم يتم تحديد أفضل نقلة بارزة في'
                    ' هذه المباراة.',
                buttonText: 'عرض النقلة',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bestWorstCard(
                title: 'أسوأ نقلة',
                icon: Icons.dangerous_rounded,
                color: const Color(0xFFD9483D),
                plyIndex: worstIdx,
                emptyText:
                    'لا توجد أخطاء كبيرة في هذه'
                    ' المباراة.',
                buttonText: 'عرض على الرقعة',
              ),
            ),
          ],
        ),
        if (brilliantIdx != null) ...[
          const SizedBox(height: 10),
          _bestWorstCard(
            title: 'نقلة مدهشة!! (Brilliant)',
            icon: Icons.auto_awesome_rounded,
            color: const Color(0xFF1BADA6),
            plyIndex: brilliantIdx,
            emptyText: '',
            buttonText: 'عرض النقلة',
          ),
        ],
        const SizedBox(height: 16),

        // --------------------------------------------------
        // أهم الأخطاء (أعلى خسارة تقييم)
        // --------------------------------------------------
        const Text(
          'أهم الأخطاء',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (this._criticalMoments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 8,
            ),
            child: Text('لا توجد أخطاء بارزة تُذكر.'),
          )
        else
          for (final m in this._criticalMoments.take(5))
            this._mistakeTile(m.plyIndex),
        const SizedBox(height: 16),

        // --------------------------------------------------
        // الفرص الضائعة
        // --------------------------------------------------
        const Text(
          'الفرص الضائعة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (missed.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 8,
            ),
            child: Text(
              'لا توجد فرص ضائعة واضحة حسب تحليل'
              ' Stockfish.',
            ),
          )
        else
          for (final i in missed) this._mistakeTile(i),
        const SizedBox(height: 16),

        // --------------------------------------------------
        // مراحل المباراة
        // --------------------------------------------------
        const Text(
          'مراحل المباراة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _phaseDetailCard('الافتتاح', 'opening'),
        const SizedBox(height: 8),
        _phaseDetailCard('وسط اللعبة', 'middlegame'),
        const SizedBox(height: 8),
        _phaseDetailCard('النهايات', 'endgame'),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _playerStatsCard(
    String name,
    double accuracy,
    double? acpl,
    Map<MoveQuality, int> counts,
  ) {
    Widget row(MoveQuality q) {
      final info = moveQualityInfo[q]!;
      final count = counts[q] ?? 0;

      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 2,
        ),
        child: Row(
          children: [
            Icon(info.icon, size: 14, color: info.color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                info.label,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${accuracy.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'دقة Chess2',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ACPL: ${acpl == null ? 'N/A' : acpl.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Divider(height: 14),
          for (final q in moveQualityDisplayOrder) row(q),
        ],
      ),
    );
  }

  Widget _bestWorstCard({
    required String title,
    required IconData icon,
    required Color color,
    required int? plyIndex,
    required String emptyText,
    required String buttonText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (plyIndex == null)
            Text(
              emptyText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            )
          else ...[
            Text(
              '${(plyIndex ~/ 2) + 1}'
              '${_plies[plyIndex].color == 'w' ? '.' : '...'} '
              '${_plies[plyIndex].san}'
              '${_sanSuffix(_qualities[plyIndex])}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'خسارة تقييم: '
              '${(_lossAt(plyIndex) / 100).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: OutlinedButton(
                onPressed: () => _jumpAndShowBoard(
                  plyIndex + 1,
                ),
                child: Text(buttonText),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// تفاصيل النقلة المحددة على الرسم البياني (من
  /// `List<MoveAnalysisResult>` نفسها التي تقرأها بقية الواجهة).
  Widget _buildGraphMoveInfo() {
    final results = _c.results;
    final k = _currentIndex - 1;

    if (results.isEmpty || k < 0 || k >= results.length) {
      return Text(
        'اضغط على الرسم لاختيار نقلة.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      );
    }

    final r = results[k];
    final info = moveQualityInfo[r.classification]!;

    String loss(int cp) => (cp.clamp(0, 1000) / 100).toStringAsFixed(2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: r.isCritical
            ? Border.all(color: Colors.amber.withValues(alpha: 0.6))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'النقلة ${r.moveNumber}${r.side == 'w' ? '.' : '...'} '
            '${r.san}  •  ${info.label}'
            '${r.isCritical ? '  •  لحظة حرجة' : ''}',
            style: TextStyle(
              color: info.color,
              fontWeight: FontWeight.bold,
            ),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 4),
          Text(
            'التقييم قبل: ${_evalLabels[k]}   بعد: ${_evalLabels[k + 1]}   '
            'الخسارة: ${loss(r.evaluationLossCp)}',
            style: const TextStyle(fontSize: 12),
          ),
          if (r.bestMoveSan.isNotEmpty && !r.isBestMove)
            Text(
              'الأفضل: ${r.bestMoveSan}',
              style: const TextStyle(fontSize: 12),
              textDirection: TextDirection.ltr,
            ),
        ],
      ),
    );
  }

  /// ACPL لكل لاعب في مرحلة معيّنة (بوحدة البيدق)، أو null.
  String? _phaseAcplText(String phaseKey) {
    if (_c.results.isEmpty) return null;

    final p = computeAcpl(_c.results).byPhase[phaseKey];

    if (p == null) return null;

    String f(double? v) => v == null ? '—' : (v / 100).toStringAsFixed(2);

    if (p['w'] == null && p['b'] == null) return null;

    return 'ACPL ⚪${f(p['w'])} ⚫${f(p['b'])}';
  }

  Widget _phaseDetailCard(String label, String phaseKey) {
    final stat = _phaseStatsFull[phaseKey]!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${stat.moveCount} نقلة',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'دقة ${stat.accuracy.toStringAsFixed(0)}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_phaseAcplText(phaseKey) != null)
                  Text(
                    _phaseAcplText(phaseKey)!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              'أخطاء: ${stat.errorCount}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: stat.errorCount > 0
                    ? const Color(0xFFD9483D)
                    : Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
