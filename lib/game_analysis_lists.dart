part of 'game_analysis_screen.dart';

/// تبويبات النقلات والأخطاء واللحظات الحرجة.
extension _AnalysisListTabs on _GameAnalysisScreenState {
  // ------------------------------------------------------------
  // تبويب: النقلات
  // ------------------------------------------------------------

  Widget _buildMovesTab() {
    if (_plies.isEmpty) {
      return const Center(
        child: Text('لا توجد نقلات.'),
      );
    }

    final rows = <Widget>[];

    for (var i = 0; i < _plies.length; i += 2) {
      final whiteP = _plies[i];
      final whiteQ =
          _qualities.length > i ? _qualities[i] : null;

      final hasBlack = i + 1 < _plies.length;
      final blackP = hasBlack ? _plies[i + 1] : null;
      final blackQ =
          hasBlack && _qualities.length > i + 1
              ? _qualities[i + 1]
              : null;

      rows.add(
        Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${(i ~/ 2) + 1}.',
                style: TextStyle(
                  color: Colors.white60,
                ),
              ),
            ),
            Expanded(
              child: _moveChip(
                whiteP.san,
                whiteQ,
                () => _jumpAndShowBoard(
                  i + 1,
                ),
                isCurrent: _currentIndex == i + 1,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: blackP == null
                  ? const SizedBox()
                  : _moveChip(
                      blackP.san,
                      blackQ,
                      () => _jumpAndShowBoard(
                        i + 2,
                      ),
                      isCurrent:
                          _currentIndex == i + 2,
                    ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: rows,
    );
  }

  Widget _moveChip(
    String san,
    MoveQuality? q,
    VoidCallback onTap, {
    bool isCurrent = false,
  }) {
    final info =
        q != null ? moveQualityInfo[q] : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: 2,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 6,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: isCurrent
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.15)
              : (info?.color.withValues(alpha: 0.10) ??
                  Colors.transparent),
          borderRadius: BorderRadius.circular(6),
          border: isCurrent
              ? Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                  width: 1.2,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (info != null) ...[
              Icon(
                info.icon,
                size: 14,
                color: info.color,
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                '$san'
                '${q != null ? _sanSuffix(q) : ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // تبويب: الأخطاء
  // ------------------------------------------------------------

  Widget _buildMistakesTab() {
    if (_analyzing) {
      return const Center(
        child: Text('التحليل جارٍ...'),
      );
    }

    final counts = this._qualityCounts;

    final flagged = <int>[];

    for (var i = 0; i < _qualities.length; i++) {
      final q = _qualities[i];

      if (q == MoveQuality.inaccuracy ||
          q == MoveQuality.mistake ||
          q == MoveQuality.blunder ||
          q == MoveQuality.miss) {
        flagged.add(i);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in [
              MoveQuality.brilliant,
              MoveQuality.best,
              MoveQuality.inaccuracy,
              MoveQuality.mistake,
              MoveQuality.blunder,
              MoveQuality.miss,
            ])
              if ((counts[q] ?? 0) > 0)
                Chip(
                  avatar: Icon(
                    moveQualityInfo[q]!.icon,
                    size: 16,
                    color: moveQualityInfo[q]!.color,
                  ),
                  label: Text(
                    '${moveQualityInfo[q]!.label}:'
                    ' ${counts[q]}',
                  ),
                ),
          ],
        ),
        const SizedBox(height: 12),
        if (flagged.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 24,
            ),
            child: Text(
              'لا توجد أخطاء أو عدم دقة تُذكر — أداء ممتاز!',
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final i in flagged)
            _mistakeTile(i),
      ],
    );
  }

  Widget _mistakeTile(int i) {
    final ply = _plies[i];
    final q = _qualities[i];
    final info = moveQualityInfo[q]!;
    final loss = _lossAt(i);
    final moveNumber = (i ~/ 2) + 1;

    final bestUci = i < _bestUci.length
        ? _bestUci[i]
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              info.color.withValues(alpha: 0.15),
          child: Icon(info.icon, color: info.color),
        ),
        title: Text(
          'النقلة $moveNumber'
          '${ply.color == 'w' ? '.' : '...'} '
          '${ply.san}${_sanSuffix(q)}',
        ),
        subtitle: Text(
          '${info.label} • خسارة تقييم'
          ' ${(loss / 100).toStringAsFixed(2)}'
          '${parseUci(bestUci) != null ? ' • الأفضل: '
              '${parseUci(bestUci)!.from}'
              '${parseUci(bestUci)!.to}' : ''}',
        ),
        onTap: () =>
            _jumpAndShowBoard(i + 1),
      ),
    );
  }

  // ------------------------------------------------------------
  // تبويب: اللحظات الحرجة
  // ------------------------------------------------------------

  Widget _buildCriticalMomentsTab() {
    if (_analyzing) {
      return const Center(
        child: Text('التحليل جارٍ...'),
      );
    }

    final moments = this._criticalMoments;

    if (moments.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد لحظات حرجة بارزة في هذه المباراة.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: moments.length,
      itemBuilder: (context, index) {
        final m = moments[index];
        final ply = _plies[m.plyIndex];
        final info = moveQualityInfo[m.quality]!;
        final moveNumber = (m.plyIndex ~/ 2) + 1;

        return Card(
          margin: const EdgeInsets.symmetric(
            vertical: 4,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  info.color.withValues(alpha: 0.15),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: info.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              'النقلة $moveNumber'
              '${ply.color == 'w' ? '.' : '...'} '
              '${ply.san}${_sanSuffix(m.quality)}',
            ),
            subtitle: Text(
              m.kind == 'only_move'
                  ? '${info.label} • نقلة وحيدة أُدّيت بدقة'
                  : (m.kind == 'tablebase'
                      ? '${info.label} • تغيّرت النتيجة المضمونة '
                          '(Tablebase)'
                      : '${info.label} • خسارة تقييم'
                          ' ${(m.lossCp / 100).toStringAsFixed(2)}'),
            ),
            onTap: () => _jumpAndShowBoard(
              m.plyIndex + 1,
            ),
          ),
        );
      },
    );
  }
}
