import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// صفحات الألغاز في التطبيق.
///
/// التصنيف يتم عند بناء الملف (tool/build_puzzles.py) بتشغيل نقلات كل لغز:
///  - [brilliant]: ألغاز فيها تضحية حقيقية.
///  - [mate]: ألغاز تنتهي بكش مات فعلًا.
///  - [training]: كل الألغاز (حلّ بلا حدود ورفع المستوى).
/// اللغز الذي فيه تضحية ثم كش مات يظهر في brilliant وفي mate معًا.
enum PuzzleCategory { brilliant, mate, training }

/// لغز Lichess متعدد الخطوات.
///
/// صيغة Lichess: [fen] هو الوضعية *قبل* نقلة الخصم، و[moves][0] هي
/// نقلة الخصم (تُلعب تلقائيًا)، ثم [moves][1] هي أول نقلة على
/// اللاعب إيجادها، وهكذا بالتناوب (جواب الخصم ثم نقلة اللاعب).
class LichessPuzzle {
  final String id;
  final String fen;
  final List<String> moves;
  final int rating;
  final List<String> themes;

  /// فيه تضحية حقيقية (صفحة بريليانت).
  final bool isBrilliant;

  /// ينتهي بكش مات (صفحة جيك ميت).
  final bool isMate;

  const LichessPuzzle({
    required this.id,
    required this.fen,
    required this.moves,
    required this.rating,
    required this.themes,
    required this.isBrilliant,
    required this.isMate,
  });

  /// لون اللاعب الذي يحلّ اللغز ('w' أو 'b'): عكس صاحب الدور في [fen]
  /// لأن أول نقلة هي للخصم.
  String get solverSide {
    final parts = fen.split(' ');
    final turn = parts.length > 1 ? parts[1] : 'w';

    return turn == 'w' ? 'b' : 'w';
  }

  /// "كش مات في N" إن وُجد ثيم mateInN.
  int? get mateIn {
    for (final t in themes) {
      final m = RegExp(r'^mateIn(\d+)$').firstMatch(t);

      if (m != null) return int.tryParse(m.group(1)!);
    }

    return null;
  }

  static LichessPuzzle? fromJson(dynamic j) {
    if (j is! Map) return null;

    final id = j['id']?.toString();
    final fen = j['fen']?.toString();
    final rawMoves = j['moves'];

    if (id == null || fen == null || rawMoves is! List) return null;

    final moves = rawMoves.map((e) => e.toString()).toList();

    // نحتاج نقلة الخصم + نقلة واحدة على الأقل للاعب.
    if (moves.length < 2) return null;

    final themes = (j['themes'] is List)
        ? (j['themes'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return LichessPuzzle(
      id: id,
      fen: fen,
      moves: moves,
      rating: (j['rating'] as num?)?.toInt() ?? 0,
      themes: themes,
      isBrilliant: j['br'] == true,
      isMate: j['mt'] == true,
    );
  }
}

class LichessPuzzleRepository {
  LichessPuzzleRepository._();

  static const String assetPath = 'assets/puzzles/lichess_puzzles.json';
  static const String _solvedKey = 'chess2_lichess_solved_v1';

  static List<LichessPuzzle>? _all;

  /// يحمّل كل الألغاز من الـ asset مرة واحدة ويُخزّنها في الذاكرة.
  static Future<List<LichessPuzzle>> loadAll() async {
    final cached = _all;

    if (cached != null) return cached;

    try {
      final raw = await rootBundle.loadString(assetPath);
      final list = jsonDecode(raw);

      if (list is! List) return <LichessPuzzle>[];

      final parsed = <LichessPuzzle>[];

      for (final j in list) {
        final puzzle = LichessPuzzle.fromJson(j);

        if (puzzle != null) parsed.add(puzzle);
      }

      _all = parsed;

      return parsed;
    } catch (_) {
      return <LichessPuzzle>[];
    }
  }

  /// ألغاز صفحة واحدة، من الأسهل إلى الأصعب.
  static Future<List<LichessPuzzle>> loadCategory(
    PuzzleCategory category,
  ) async {
    final all = await loadAll();

    final list = all.where((p) {
      switch (category) {
        case PuzzleCategory.brilliant:
          return p.isBrilliant;
        case PuzzleCategory.mate:
          return p.isMate;
        case PuzzleCategory.training:
          return true;
      }
    }).toList();

    list.sort((a, b) => a.rating.compareTo(b.rating));

    return list;
  }

  static Future<Set<String>> loadSolved() async {
    try {
      final p = await SharedPreferences.getInstance();

      return (p.getStringList(_solvedKey) ?? <String>[]).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> markSolved(String id) async {
    try {
      final p = await SharedPreferences.getInstance();
      final set = (p.getStringList(_solvedKey) ?? <String>[]).toSet();

      if (set.add(id)) {
        await p.setStringList(_solvedKey, set.toList());
      }
    } catch (_) {}
  }
}
