import 'dart:convert';

import 'coach_models.dart';

/// بناء Prompt النموذج المحلي وقراءة ناتجه (JSON منظّم).
///
/// القاعدة: النموذج يشرح فقط. لا يحسب تقييمًا ولا نقلة ولا تصنيفًا؛
/// وأي ناتج يذكر نقلة غير موجودة في بيانات المحرك يُرفض ويُستبدل
/// بالقالب.
class CoachPromptEngine {
  CoachPromptEngine._();

  static String _langName(CoachLang l) =>
      l == CoachLang.ar ? 'Arabic' : 'English';

  static String _styleFor(CoachLevel level) {
    switch (level) {
      case CoachLevel.beginner:
        return 'The player is a BEGINNER. Use very simple words, short '
            'sentences, no jargon, no numbers.';
      case CoachLevel.intermediate:
        return 'The player is INTERMEDIATE. Use clear language, mention '
            'basic tactics and principles.';
      case CoachLevel.advanced:
        return 'The player is ADVANCED. Use tactical and positional '
            'terms, be precise and compact.';
      case CoachLevel.expert:
        return 'The player is an EXPERT. Be concise and technical; focus '
            'on concrete ideas, critical alternatives and plans.';
    }
  }

  static const String _schema = '''
Return ONLY one JSON object, no markdown, no extra text:
{"title": string, "summary": string, "explanation": string,
 "betterMove": string or null, "idea": string or null, "lesson": string}''';

  /// رسالة النظام (ثابتة لكل الطلبات).
  static String system({
    required CoachLevel level,
    required CoachLang lang,
  }) {
    return 'You are a friendly chess coach inside a mobile app. '
        'A chess engine (Stockfish) already analysed the position; you '
        'only EXPLAIN its result to the player.\n'
        'Rules:\n'
        '- Use only the supplied engine data.\n'
        '- Do not invent engine evaluations.\n'
        '- Do not invent moves. Mention only moves that appear in the '
        'supplied data.\n'
        '- Do not calculate a different best move.\n'
        '- Do not decide legality, winner, mate or classification.\n'
        '- FEN is provided only as board context. Do not derive a new best move from it.\n'
        '- ${_styleFor(level)}\n'
        '- response_language = ${lang.name}. Write every text field in '
        '${_langName(lang)}. Keep chess move notation as given.\n'
        '$_schema';
  }

  /// شرح نقلة. [revealBest] = false في وضع التدريب (لا نكشف الحل).
  /// [deep] = «اشرح أكثر».
  static String move(
    CoachMoveInput input, {
    required CoachLevel level,
    required CoachLang lang,
    bool revealBest = false,
    bool deep = false,
    List<String> playerFacts = const [],
  }) {
    final data = const JsonEncoder.withIndent('  ')
        .convert(input.toJson(revealBest: revealBest));

    final b = StringBuffer()
      ..writeln('Stockfish engine result. FEN is provided as board context; '
          'all move claims must come only from the supplied move/PV fields.')
      ..writeln('Evaluations are in pawns from the point '
          'of view of the player who moved; positive = good for them:')
      ..writeln(data)
      ..writeln();

    if (playerFacts.isNotEmpty) {
      b.writeln('Facts about this player (from past games):');

      for (final f in playerFacts) {
        b.writeln('- $f');
      }

      b.writeln();
    }

    if (deep) {
      b
        ..writeln('Explain this position more deeply. Focus on:')
        ..writeln('- the tactical idea')
        ..writeln('- the positional idea')
        ..writeln("- the opponent's threat")
        ..writeln('- why the alternative move is stronger')
        ..writeln('- what the player should learn');
    } else {
      b
        ..writeln('Explain:')
        ..writeln('1. What the player did.')
        ..writeln('2. Why it received this classification.');

      if (revealBest) {
        b
          ..writeln('3. Why the best move was stronger.')
          ..writeln('4. The chess idea behind the best move.');
      } else {
        b
          ..writeln('3. The general idea the player should look for '
              '(do NOT name or hint at the best move).')
          ..writeln('4. Leave "betterMove" as null.');
      }

      b.writeln('5. Give one short lesson.');
    }

    b
      ..writeln()
      ..writeln('Keep it concise: summary max 1 sentence, explanation '
          'max ${deep ? 5 : 3} sentences.')
      ..writeln('Answer in ${_langName(lang)}.');

    return b.toString();
  }

  static String position(
    CoachPositionInput p, {
    required CoachLevel level,
    required CoachLang lang,
  }) {
    final data = const JsonEncoder.withIndent('  ').convert(p.toJson());

    return 'Engine result for this position (evaluation in pawns from '
        "White's point of view):\n$data\n\n"
        'Explain the position to the player: who is better and why, the '
        'plan behind the best move, and one lesson.\n'
        'Answer in ${_langName(lang)}.';
  }

  static String game(
    Map<String, dynamic> stats, {
    required CoachLevel level,
    required CoachLang lang,
    List<String> playerFacts = const [],
  }) {
    final data = const JsonEncoder.withIndent('  ').convert(stats);

    final b = StringBuffer()
      ..writeln('Engine statistics for a finished game:')
      ..writeln(data)
      ..writeln();

    if (playerFacts.isNotEmpty) {
      b.writeln('Facts about this player (from past games):');

      for (final f in playerFacts) {
        b.writeln('- $f');
      }

      b.writeln();
    }

    b
      ..writeln('Summarize the game for the player and give personal '
          'advice based only on these numbers and facts. Set '
          '"betterMove" and "idea" to null.')
      ..writeln('Answer in ${_langName(lang)}.');

    return b.toString();
  }

  // ------------------------------------------------------------
  // قراءة الناتج + الحواجز
  // ------------------------------------------------------------

  /// يستخرج أول JSON من ناتج النموذج (يتجاهل الأسوار البرمجية ووسم think).
  static Map<String, dynamic>? extractJson(String raw) {
    var t = raw.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');

    t = t.replaceAll('```json', '').replaceAll('```', '');

    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');

    if (start < 0 || end <= start) return null;

    try {
      final v = jsonDecode(t.substring(start, end + 1));

      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  // نمط SAN: O-O / O-O-O / [KQRBN]?[a-h]?[1-8]?x?[a-h][1-8](=Q)?
  static final RegExp _san = RegExp(
    r'(?<![A-Za-z0-9])'
    r'(O-O-O|O-O|[KQRBN]?[a-h]?[1-8]?x?[a-h][1-8](?:=[QRBN])?)'
    r'[+#]?(?![A-Za-z0-9])',
  );

  static String _norm(String san) => san.replaceAll(RegExp(r'[+#x]'), '');

  /// true إذا ذكر [text] نقلة بصيغة SAN ليست ضمن [allowed].
  static bool mentionsUnknownMove(String text, Set<String> allowed) {
    final ok = allowed.map(_norm).toSet();

    for (final m in _san.allMatches(text)) {
      final tok = _norm(m.group(1)!);

      // رموز قصيرة جدًا مثل "a1" قد تكون مربعات لا نقلات؛ نسمح
      // بالمربعات المجردة الموجودة كجزء من نقلة مسموحة.
      if (ok.contains(tok)) continue;

      final isSquare = RegExp(r'^[a-h][1-8]$').hasMatch(tok);

      if (isSquare && ok.any((a) => a.endsWith(tok) || a.contains(tok))) {
        continue;
      }

      return true;
    }

    return false;
  }

  /// يحوّل ناتج النموذج إلى [CoachExplanation] أو null إذا كان غير
  /// صالح (JSON تالف، أو ذكر نقلة غير موجودة في بيانات المحرك).
  static CoachExplanation? parse(
    String raw, {
    required Set<String> allowedMoves,
    String? trustedBetterMove,
  }) {
    final json = extractJson(raw);

    if (json == null) return null;

    final e = CoachExplanation.fromJson(json, fromModel: true);

    if (e == null) return null;

    final text = [e.title, e.summary, e.explanation, e.idea, e.lesson]
        .whereType<String>()
        .join(' ');

    if (mentionsUnknownMove(text, allowedMoves)) return null;

    // betterMove يأتي من المحرك دائمًا، لا من النموذج.
    return CoachExplanation(
      title: e.title,
      summary: e.summary,
      explanation: e.explanation,
      betterMove: trustedBetterMove,
      idea: e.idea,
      lesson: e.lesson,
      fromModel: true,
    );
  }
}
