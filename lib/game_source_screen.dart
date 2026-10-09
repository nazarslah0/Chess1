import 'package:flutter/material.dart';

import 'game_analysis_screen.dart';
import 'game_source.dart';
import 'source_style.dart';

/// شاشة البحث والتحليل لحسابات المصادر (Chess.com / Lichess) — شاشة
/// واحدة موحّدة بنمط Chess.com لكل المصادر.
///
/// - تحفظ آخر Username لكل مصدر محليًا وتعيد تحميله تلقائيًا.
/// - تجلب آخر 50 مباراة تلقائيًا (بلا اختيار 10/25/50).
/// - زر تبديل الحساب يفتح حسابًا آخر ويحفظه.
/// - اختيار مباراة يفتح [GameAnalysisScreen] نفسها لكل المصادر.
class GameSourceScreen extends StatefulWidget {
  final GameSource source;

  const GameSourceScreen({super.key, required this.source});

  @override
  State<GameSourceScreen> createState() => _GameSourceScreenState();
}

class _GameSourceScreenState extends State<GameSourceScreen> {
  static const int _limit = 50;

  final TextEditingController _usernameCtrl = TextEditingController();

  bool _loadingGames = false;
  String? _error;
  List<SourceGame> _games = <SourceGame>[];
  String _username = '';
  String? _savedUsername;

  GameSource get _source => widget.source;

  @override
  void initState() {
    super.initState();
    _restoreAccount();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreAccount() async {
    final saved = await _source.savedUsername();

    if (!mounted || saved == null) return;

    setState(() {
      _savedUsername = saved;
      _usernameCtrl.text = saved;
      _username = saved;
    });

    // بعد حفظ الحساب، يعاد تحميل آخر 50 مباراة تلقائيًا.
    await _search(saved);
  }

  Future<void> _search([String? requestedUsername]) async {
    final u = (requestedUsername ?? _usernameCtrl.text).trim();

    if (u.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _loadingGames = true;
      _error = null;
      _games = <SourceGame>[];
      _username = u;
    });

    try {
      await _source.verifyUsername(u);

      final games = await _source.fetchRecentGames(u, limit: _limit);

      await _source.saveUsername(u);

      if (!mounted) return;

      setState(() {
        _savedUsername = u;
        _usernameCtrl.text = u;
        _games = games;
        _loadingGames = false;

        if (games.isEmpty) {
          _error = 'لا توجد مباريات ظاهرة لهذا الحساب.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _source.errorMessage(e);
        _loadingGames = false;
      });
    }
  }

  Future<void> _switchAccount() async {
    final controller = TextEditingController(text: _username);

    final username = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تبديل حساب ${_source.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'اسم المستخدم',
            hintText: 'مثال: ${_source.usernameHint}',
            prefixIcon: const Icon(Icons.person_search_rounded),
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('تبديل'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (username == null || username.trim().isEmpty) return;

    _usernameCtrl.text = username.trim();

    await _search(username.trim());
  }

  void _openGame(SourceGame g) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameAnalysisScreen(
          pgn: g.pgn,
          whiteLabel: g.whiteLabel(_username),
          blackLabel: g.blackLabel(_username),
          resultLabel: g.resultLabel(_username),
          sourceLabel: _source.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SourceScaffold(
      title: 'تحليل مباريات ${_source.name}',
      actions: [
        if (_savedUsername != null)
          IconButton(
            tooltip: 'تبديل الحساب',
            onPressed: _loadingGames ? null : _switchAccount,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
      ],
      body: Column(
        children: [
          _buildAccountHeader(),
          _buildSearchRow(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  _error!,
                  style: const TextStyle(color: SourceStyle.error),
                ),
              ),
            ),
          _buildListHeader(),
          Expanded(child: _buildGamesList()),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _usernameCtrl,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.search,
              decoration: SourceStyle.input(
                label: 'اسم مستخدم ${_source.name}',
                hint: 'مثال: ${_source.usernameHint}',
                icon: Icons.person_outline,
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 56,
            child: FilledButton(
              style: SourceStyle.primaryButton(),
              onPressed: _loadingGames ? null : _search,
              child: _loadingGames
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('بحث'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          const Text(
            'آخر $_limit مباراة',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          if (_games.isNotEmpty)
            Text(
              '${_games.length} مباراة',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildGamesList() {
    if (_games.isEmpty) {
      return Center(
        child: _loadingGames
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: SourceStyle.green),
                  SizedBox(height: 12),
                  Text(
                    'جاري تحميل آخر $_limit مباراة...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'أدخل اسم حسابك على ${_source.name} ثم سيتم تحميل آخر '
                  '$_limit مباراة تلقائيًا وحفظ الحساب.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
      itemCount: _games.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _buildGameTile(_games[index], index),
    );
  }

  Widget _buildAccountHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: SourceStyle.panel,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: SourceStyle.avatar,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: SourceStyle.green,
              size: 28,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الحساب المحفوظ',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                Text(
                  _savedUsername ?? 'لم يتم اختيار حساب',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          if (_savedUsername != null)
            TextButton.icon(
              onPressed: _loadingGames ? null : _switchAccount,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('تبديل'),
              style: TextButton.styleFrom(
                foregroundColor: SourceStyle.green,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameTile(SourceGame g, int index) {
    final outcome = g.outcomeFor(_username);
    final opponent = g.opponentOf(_username);

    final Color color;
    final String label;
    final IconData icon;

    switch (outcome) {
      case 'win':
        color = SourceStyle.green;
        label = 'فوز';
        icon = Icons.emoji_events_rounded;
      case 'draw':
        color = SourceStyle.draw;
        label = 'تعادل';
        icon = Icons.horizontal_rule_rounded;
      default:
        color = SourceStyle.loss;
        label = 'خسارة';
        icon = Icons.close_rounded;
    }

    final date = g.endTime;
    final dateStr = date == null
        ? ''
        : '${date.year}/${date.month.toString().padLeft(2, '0')}'
            '/${date.day.toString().padLeft(2, '0')}';

    return Material(
      color: SourceStyle.tile,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openGame(g),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 19,
                backgroundColor: color.withValues(alpha: .15),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ضد $opponent',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${g.timeClass.isEmpty ? _source.name : g.timeClass}'
                      ' • $dateStr',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
