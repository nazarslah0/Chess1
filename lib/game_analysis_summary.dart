part of 'game_analysis_screen.dart';

/// شاشتا «جاري التحليل» و«ملخص ما قبل المراجعة».
extension _AnalysisStageViews on _GameAnalysisScreenState {
  Widget _buildStageTopBar(String title) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              textDirection: TextDirection.ltr,
              color: Colors.white70,
              size: 30,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// أثناء التحليل: الرقعة بلا أسهم ولا علامات + شريط تقدّم.
  Widget _buildAnalyzingView() {
    return LayoutBuilder(
      builder: (context, c) {
        final side = math.min(
          c.maxWidth - 32,
          math.max(160.0, c.maxHeight - 260),
        );

        return Column(
          children: [
            _buildStageTopBar('مراجعة المباراة'),
            const Spacer(),
            SizedBox(
              width: side,
              height: side,
              child: this._buildBoard(),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                color: _green,
                backgroundColor: const Color(0xFF3A3937),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'جارٍ تحليل المباراة... '
              '$_analyzedCount من ${_fens.length}'
              ' (${(_progress * 100).round()}%)',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            TextButton(
              onPressed: _cancelAnalysis,
              child: const Text('إلغاء التحليل'),
            ),
            const Spacer(),
          ],
        );
      },
    );
  }

  /// صفحة الإحصائيات بعد انتهاء التحليل (على طراز chess.com):
  /// رسم التقييم، الدقة، وعدد النقلات من كل تصنيف لكل لاعب.
  Widget _buildSummaryView() {
    final acc = this._accuracyBySide;
    final counts = this._qualityCountsBySide;

    final accW = acc['w'] ?? 0;
    final accB = acc['b'] ?? 0;

    final result = _headers['Result'] ?? '';
    final whiteWon = result == '1-0';
    final blackWon = result == '0-1';

    Widget cell(Widget child) => Center(child: child);

    Widget row({
      required Widget label,
      required Widget black,
      required Widget mid,
      required Widget white,
    }) {
      // RTL: أول عنصر في أقصى اليمين → (العنوان، الأسود، الوسط، الأبيض).
      return Row(
        children: [
          Expanded(flex: 7, child: label),
          Expanded(flex: 3, child: black),
          Expanded(flex: 3, child: mid),
          Expanded(flex: 3, child: white),
        ],
      );
    }

    Widget labelText(String s) => Text(
          s,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        );

    Widget playerHead({
      required String name,
      required String color,
      required bool winner,
    }) {
      final isWhite = color == 'w';

      return Column(
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isWhite
                  ? const Color(0xFFE8E8E8)
                  : const Color(0xFF5A5856),
              borderRadius: BorderRadius.circular(6),
              border: winner
                  ? Border.all(color: _green, width: 3)
                  : null,
            ),
            child: Image.asset(
              chessComPieceTheme.assetPath(color, 'P'),
              fit: BoxFit.contain,
            ),
          ),
        ],
      );
    }

    Widget accBox(double value, bool higher) {
      return Container(
        width: 92,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: higher
              ? const Color(0xFFF0F0F0)
              : const Color(0xFF454341),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          value.toStringAsFixed(1),
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: higher
                ? const Color(0xFF262522)
                : Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    final whiteHigher = accW > accB;
    final blackHigher = accB > accW;

    return Column(
      children: [
        _buildStageTopBar('مراجعة المباراة'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              children: [
                // ---------------- رسم التقييم ----------------
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 104,
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) {
                            if (_fens.length < 2 || c.maxWidth <= 0) {
                              return;
                            }

                            final idx = (d.localPosition.dx /
                                    c.maxWidth *
                                    (_fens.length - 1))
                                .round()
                                .clamp(0, _fens.length - 1);

                            _startReview(index: idx);
                          },
                          child: CustomPaint(
                            painter: _SummaryGraphPainter(
                              evalPawns: _evalPawns,
                              qualities: _qualities,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ---------------- اللاعبان ----------------
                row(
                  label: labelText('اللاعبَين'),
                  black: cell(
                    playerHead(
                      name: _blackName,
                      color: 'b',
                      winner: blackWon,
                    ),
                  ),
                  mid: const SizedBox(),
                  white: cell(
                    playerHead(
                      name: _whiteName,
                      color: 'w',
                      winner: whiteWon,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ---------------- الدقة ----------------
                row(
                  label: labelText('الدقة'),
                  black: cell(accBox(accB, blackHigher)),
                  mid: const SizedBox(),
                  white: cell(accBox(accW, whiteHigher)),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF45433F), height: 1),
                const SizedBox(height: 8),

                // ---------------- عدد النقلات لكل تصنيف ----------------
                for (final q in moveQualityDisplayOrder)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: row(
                      label: labelText(moveQualityInfo[q]!.label),
                      black: cell(
                        Text(
                          '${counts['b']![q] ?? 0}',
                          style: TextStyle(
                            color: moveQualityInfo[q]!.color,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      mid: cell(QualityBadge(quality: q, size: 34)),
                      white: cell(
                        Text(
                          '${counts['w']![q] ?? 0}',
                          style: TextStyle(
                            color: moveQualityInfo[q]!.color,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_cancelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'تم إلغاء التحليل عند النقلة $_analyzedCount'
                      ' من ${_fens.length}، فالإحصائيات تخص النقلات'
                      ' المحلَّلة فقط.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange.shade300,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ---------------- متابعة المراجعة ----------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Material(
            color: _green,
            borderRadius: BorderRadius.circular(10),
            elevation: 3,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _startReview,
              child: const SizedBox(
                width: double.infinity,
                height: 60,
                child: Center(
                  child: Text(
                    'متابعة المراجعة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
