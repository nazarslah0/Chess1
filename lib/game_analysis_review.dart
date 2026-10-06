part of 'game_analysis_screen.dart';

/// شاشة المراجعة: الشريط العلوي، النقلات، الرقعة، اللاعبون، الأزرار.
extension _AnalysisReviewView on _GameAnalysisScreenState {
  Widget _buildTopBar() {
    return Container(
      height: 52,
      color: _bg,
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
                widget.sourceLabel.isEmpty
                    ? 'تحليل المباراة'
                    : widget.sourceLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _resultText,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- شريط النقلات الأفقي ----------------

  void _scrollStripToCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_currentIndex <= 0) {
        if (_stripCtrl.hasClients) {
          _stripCtrl.animateTo(
            0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
        return;
      }

      final ctx = _stripKeys[_currentIndex]?.currentContext;

      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMoveStrip() {
    final items = <Widget>[];

    for (var i = 0; i < _plies.length; i += 2) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '.${(i ~/ 2) + 1}',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 15,
            ),
          ),
        ),
      );

      items.add(_stripMove(i));

      if (i + 1 < _plies.length) {
        items.add(_stripMove(i + 1));
      }
    }

    return Container(
      height: 46,
      color: _panel,
      child: SingleChildScrollView(
        controller: _stripCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: items),
      ),
    );
  }

  Widget _stripMove(int k) {
    final ply = _plies[k];
    final selected = _currentIndex == k + 1;
    final key = _stripKeys.putIfAbsent(k + 1, () => GlobalKey());

    final q = k < _qualities.length ? _qualities[k] : null;

    Color textColor = Colors.white;

    if (q == MoveQuality.brilliant ||
        q == MoveQuality.blunder ||
        q == MoveQuality.mistake ||
        q == MoveQuality.miss ||
        q == MoveQuality.inaccuracy) {
      textColor = moveQualityInfo[q]!.color;
    }

    final first = ply.san.isEmpty ? '' : ply.san[0];
    final hasFigurine = 'KQRBN'.contains(first) && first.isNotEmpty;

    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () => _goTo(k + 1),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 2,
          vertical: 7,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF5A5856)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasFigurine) ...[
                Image.asset(
                  chessComPieceTheme.assetPath(ply.color, first),
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 2),
              ],
              Text(
                hasFigurine ? ply.san.substring(1) : ply.san,
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: selected
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- شريط التقييم الأفقي ----------------

  Widget _buildEvalStrip() {
    final hasEval = _evalPawns.isNotEmpty;

    final pawns = hasEval ? _evalPawns[_currentIndex] : 0.0;
    final label = hasEval ? _evalLabels[_currentIndex] : '0.00';

    final frac = ((pawns.clamp(-8.0, 8.0) + 8.0) / 16.0)
        .clamp(0.0, 1.0)
        .toDouble();

    final whiteBetter = frac >= 0.5;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: 16,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: const Color(0xFF403D39)),
            ),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: frac,
                child: Container(color: Colors.white),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: whiteBetter
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: whiteBetter
                          ? const Color(0xFF2B2B2B)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- الرقعة ----------------

  Widget _buildBoard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // سحب يمين/يسار للتنقل بين النقلات.
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity;

        if (v == null) return;

        if (v < -150) {
          _goTo(_currentIndex + 1);
        } else if (v > 150) {
          _goTo(_currentIndex - 1);
        }
      },
      child: AppBoard(
        key: _analysisBoardKey,
        state: _boardState,
        maxWidth: null,
        arrows: _showArrows
            ? _arrowsForCurrent()
            : const <BoardArrow>[],
        badges: _badgesForCurrent(),
        showCoordinates: _showCoords,
        interactive: false,
      ),
    );
  }

  // ---------------- شريط اللاعب ----------------

  Widget _buildPlayerBar(String color) {
    final isWhite = color == 'w';

    final name = isWhite ? _whiteName : _blackName;
    final elo = _headers[isWhite ? 'WhiteElo' : 'BlackElo'];

    final fenParts = _fens[_currentIndex].split(' ');
    final toMove = fenParts.length > 1 ? fenParts[1] : 'w';
    final active = toMove == color;

    final acc = _qualities.isNotEmpty
        ? this._accuracyBySide[color]
        : null;

    final title = (elo != null && elo.isNotEmpty && elo != '?')
        ? '($elo) $name'
        : name;

    return Container(
      color: _bg,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isWhite
                  ? const Color(0xFFE8E8E8)
                  : const Color(0xFF5A5856),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Image.asset(
              chessComPieceTheme.assetPath(color, 'P'),
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 92,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF1F1E1C)
                  : const Color(0xFF5F5E5C),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  acc == null ? '—' : acc.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'الدقة',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- لوحة المعلومات تحت الرقعة ----------------

  Widget _buildInfoPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: [
          if (_analyzing) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'جارٍ تحليل المباراة... '
                    '$_analyzedCount من ${_fens.length}'
                    ' (${(_progress * 100).round()}%)',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _cancelAnalysis,
                  child: const Text('إلغاء'),
                ),
              ],
            ),
            LinearProgressIndicator(
              value: _progress,
              color: _green,
              backgroundColor: const Color(0xFF3A3937),
            ),
            const SizedBox(height: 8),
          ],
          if (_cancelled)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'تم إلغاء التحليل عند النقلة $_analyzedCount'
                ' من ${_fens.length}. النتائج قبل هذه النقطة'
                ' محفوظة، والباقي غير محلَّل.',
                style: TextStyle(
                  color: Colors.orange.shade300,
                  fontSize: 12,
                ),
              ),
            ),
          if (_servedFromCache && !_analyzing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'نتائج محفوظة من تحليل سابق لهذه المباراة.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade300,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!_analyzing && _plies.isNotEmpty)
            this._buildCurrentMoveInfo(),
        ],
      ),
    );
  }

  // ---------------- الشريط السفلي ----------------

  Widget _buildBottomBar() {
    final atStart = _currentIndex <= 0;
    final atEnd = _currentIndex >= _fens.length - 1;

    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: _BarButton(
              icon: Icons.format_list_bulleted_rounded,
              label: 'الخيارات',
              onTap: _openOptions,
            ),
          ),
          Expanded(
            child: Center(
              child: Material(
                color: _green,
                borderRadius: BorderRadius.circular(14),
                elevation: 3,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _openReview,
                  child: const SizedBox(
                    width: 70,
                    height: 58,
                    child: Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _BarButton(
              icon: Icons.chevron_left_rounded,
              label: 'رجوع',
              enabled: !atStart,
              repeat: true,
              onTap: () => _goTo(_currentIndex - 1),
            ),
          ),
          Expanded(
            child: _BarButton(
              icon: Icons.chevron_right_rounded,
              label: 'تقدّم',
              enabled: !atEnd,
              repeat: true,
              onTap: () => _goTo(_currentIndex + 1),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- قائمة الخيارات ----------------

  void _openOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      builder: (ctx) {
        return Theme(
          data: _darkTheme(),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.swap_vert_rounded),
                      title: const Text('قلب الرقعة'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _update(() {
                          _boardState.flipBoard();
                        });
                      },
                    ),
                    SwitchListTile(
                      secondary:
                          const Icon(Icons.arrow_right_alt_rounded),
                      title: const Text('إظهار الأسهم'),
                      value: _showArrows,
                      onChanged: (v) {
                        setSheet(() {});
                        _update(() {
                          _showArrows = v;
                        });
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.stars_rounded),
                      title: const Text('إظهار علامات النقلات'),
                      value: _showBadges,
                      onChanged: (v) {
                        setSheet(() {});
                        _update(() {
                          _showBadges = v;
                        });
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.align_vertical_center),
                      title: const Text('إظهار شريط التقييم'),
                      value: _showEval,
                      onChanged: (v) {
                        setSheet(() {});
                        _update(() {
                          _showEval = v;
                        });
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.grid_on_rounded),
                      title: const Text('إظهار إحداثيات الرقعة'),
                      value: _showCoords,
                      onChanged: (v) {
                        setSheet(() {});
                        _update(() {
                          _showCoords = v;
                        });
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.copy_rounded),
                      title: const Text('نسخ PGN'),
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.pgn),
                        );
                        Navigator.pop(ctx);
                        showAppSnack(context, 'تم نسخ PGN');
                      },
                    ),
                    if (_analyzing)
                      ListTile(
                        leading: const Icon(Icons.cancel_outlined),
                        title: const Text('إلغاء التحليل'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _cancelAnalysis();
                        },
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ---------------- مراجعة المباراة (النجمة الخضراء) ----------------

  Future<void> _openReview() async {
    _sheetOpen = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (ctx) {
        final h = MediaQuery.of(ctx).size.height * 0.88;

        return Theme(
          data: _darkTheme(),
          child: ListenableBuilder(
            listenable: _sheetTick,
            builder: (ctx, _) {
              return SizedBox(
                height: h,
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: _green,
                      unselectedLabelColor: Colors.white70,
                      indicatorColor: _green,
                      tabs: const [
                        Tab(text: 'ملخص'),
                        Tab(text: 'تقرير المباراة'),
                        Tab(text: 'النقلات'),
                        Tab(text: 'الأخطاء'),
                        Tab(text: 'اللحظات الحرجة'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          this._buildSummaryTab(),
                          this._buildReportTab(),
                          this._buildMovesTab(),
                          this._buildMistakesTab(),
                          this._buildCriticalMomentsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    _sheetOpen = false;
  }
}
