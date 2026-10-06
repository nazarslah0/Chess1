import 'dart:async';

import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'board_input.dart';
import 'models.dart';
import 'puzzle_storage.dart';
import 'sound_service.dart';
import 'uci_utils.dart';

/// تمارين من مبارياتك: وضعيات فاتتك فيها نقلة قوية (يفوّتها غالبًا
/// لاعبو مستواك بحسب Maia). تُستخرج تلقائيًا عند تحليل أي مباراة.
class PuzzlesScreen extends StatefulWidget {
  const PuzzlesScreen({super.key});

  @override
  State<PuzzlesScreen> createState() => _PuzzlesScreenState();
}

class _PuzzlesScreenState extends State<PuzzlesScreen> {
  final GameState _state = GameState();
  late final BoardInput _input = BoardInput(_state);
  final SoundService _sound = SoundService();

  List<PuzzleItem> _items = <PuzzleItem>[];
  int _index = 0;
  bool _loading = true;

  String? _feedback;
  Color _feedbackColor = AppColors.muted;
  bool _revealed = false;
  bool _solved = false;

  @override
  void initState() {
    super.initState();

    _state.onSound = (kind) => _sound.playKind(kind);
    _state.addListener(_onState);

    _reload();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _state.removeListener(_onState);
    _sound.dispose();
    _state.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final items = await PuzzleStorage.load();

    // غير المحلولة أولًا.
    items.sort((a, b) {
      final sa = a.solvedCount > 0 ? 1 : 0;
      final sb = b.solvedCount > 0 ? 1 : 0;

      if (sa != sb) return sa - sb;

      return b.createdAt.compareTo(a.createdAt);
    });

    if (!mounted) return;

    setState(() {
      _items = items;
      _index = 0;
      _loading = false;
    });

    _loadCurrent();
  }

  PuzzleItem? get _current =>
      _items.isEmpty ? null : _items[_index.clamp(0, _items.length - 1)];

  void _loadCurrent() {
    final p = _current;

    if (p == null) return;

    _state.loadFen(p.fen);
    _state.flipped = p.turn == 'b';
    _input.clear();

    setState(() {
      _feedback = null;
      _revealed = false;
      _solved = false;
    });
  }

  void _go(int delta) {
    if (_items.isEmpty) return;

    setState(() {
      _index = (_index + delta) % _items.length;

      if (_index < 0) _index += _items.length;
    });

    _loadCurrent();
  }

  Future<String?> _askPromotion() async => 'q';

  bool _isBest(PuzzleItem p, String uci) =>
      isSameUciMove(p.bestUci, uci);

  Future<void> _onTap(String square) async {
    final p = _current;

    if (p == null || _solved || _revealed) return;

    final moved = await _input.tap(
      square,
      _askPromotion,
      side: p.turn,
    );

    if (!mounted) return;

    setState(() {});

    if (!moved) return;

    final uci = _input.lastUci ?? '';

    if (_isBest(p, uci)) {
      setState(() {
        _solved = true;
        _feedback = 'صحيح! هذه أفضل نقلة ✅';
        _feedbackColor = AppColors.success;
      });

      PuzzleStorage.markSolved(p.id);

      return;
    }

    setState(() {
      _feedback = 'ليست الأفضل — حاول مرة أخرى';
      _feedbackColor = AppColors.error;
    });

    final shown = _index;

    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted || shown != _index || _solved || _revealed) return;

    // نعيد الوضعية الأصلية ونُبقي رسالة الخطأ.
    _state.loadFen(p.fen);
    _state.flipped = p.turn == 'b';
    _input.clear();

    setState(() {});
  }

  void _reveal() {
    final p = _current;

    if (p == null) return;

    _state.loadFen(p.fen);
    _state.flipped = p.turn == 'b';
    _input.clear();

    setState(() {
      _revealed = true;
      _feedback = null;
    });
  }

  Future<void> _delete() async {
    final p = _current;

    if (p == null) return;

    await PuzzleStorage.remove(p.id);

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final p = _current;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          p == null
              ? 'تمارين من مبارياتك'
              : 'تمرين ${_index + 1} / ${_items.length}',
        ),
        actions: [
          if (p != null)
            IconButton(
              tooltip: 'حذف التمرين',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const LoadingView()
            : (p == null ? _buildEmpty() : _buildPuzzle(p)),
      ),
    );
  }

  Widget _buildEmpty() {
    return const CenteredMessage(
      'لا توجد تمارين بعد.\n\n'
      'حلّل بعض مبارياتك، وستظهر هنا تلقائيًا الوضعيات التي '
      'فاتتك فيها نقلة قوية.\n'
      'تأكد من كتابة اسمك في الإعدادات ليعرف التطبيق أي لاعب '
      'أنت.',
    );
  }

  Widget _buildPuzzle(PuzzleItem p) {
    final sideName = p.turn == 'w' ? 'الأبيض' : 'الأسود';

    final maiaText = (p.maiaBestProb != null && p.maiaBucket != null)
        ? 'يجدها ${_pct(p.maiaBestProb!)} فقط من لاعبي ${p.maiaBucket}'
        : null;

    final showSolution = _revealed || _solved;

    final best = showSolution ? parseUci(p.bestUci) : null;

    return PuzzleLayout(
      title: 'الدور على $sideName — جِد أفضل نقلة',
      subtitle: [
        if (p.label.isNotEmpty) p.label,
        ?maiaText,
        if (p.solvedCount > 0) 'حُلّ ${p.solvedCount}×',
      ].join(' • '),
      board: AppBoard(
        state: _state,
        onTap: _onTap,
        targets: _input.targets,
        arrowFrom: best?.from,
        arrowTo: best?.to,
      ),
      feedback: _feedback,
      feedbackColor: _feedbackColor,
      solution: showSolution
          ? SolutionCard(
              children: [
                Text(
                  'الحل: ${p.bestSan}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textDirection: TextDirection.ltr,
                ),
                if (p.playedSan.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'في المباراة لُعبت: ${p.playedSan}',
                    style: const TextStyle(color: AppColors.muted),
                    textDirection: TextDirection.ltr,
                  ),
                ],
                if (p.line.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'الخط: ${p.line}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ],
            )
          : null,
      actions: [
        OutlinedButton(
          onPressed: _items.length > 1 ? () => _go(-1) : null,
          child: const Text('السابق'),
        ),
        if (!showSolution)
          FilledButton.tonal(
            onPressed: _reveal,
            child: const Text('أرني الحل'),
          ),
        if (_revealed || _solved)
          OutlinedButton(
            onPressed: _loadCurrent,
            child: const Text('أعد المحاولة'),
          ),
        FilledButton(
          onPressed: _items.length > 1 ? () => _go(1) : null,
          child: const Text('التالي'),
        ),
      ],
    );
  }

  static String _pct(double p) {
    final v = p * 100;

    return v < 1 ? 'أقل من 1%' : '${v.toStringAsFixed(0)}%';
  }
}
