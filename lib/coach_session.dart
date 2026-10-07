import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'analysis_result.dart';
import 'coach_models.dart';
import 'game_review_models.dart';

/// ذاكرة المدرب: إحصاءات مجمّعة عن أداء اللاعب عبر المباريات
/// (محفوظة محليًا فقط). يستخدمها المدرب لنصائح شخصية.
class CoachSession {
  int games = 0;
  int moves = 0;
  int lossSumCp = 0;
  int best = 0;
  int brilliant = 0;
  int inaccuracies = 0;
  int mistakes = 0;
  int blunders = 0;

  /// أخطاء (inaccuracy+mistake+miss+blunder) حسب المرحلة.
  final Map<String, int> errorsByPhase = {
    'opening': 0,
    'middlegame': 0,
    'endgame': 0,
  };

  /// ACPL لآخر مباريات (الأحدث في النهاية، بحد أقصى 10).
  final List<int> recentAcpl = [];

  int get totalErrors => inaccuracies + mistakes + blunders;

  int get acpl => moves == 0 ? 0 : (lossSumCp / moves).round();

  Map<String, dynamic> toJson() => {
        'games': games,
        'moves': moves,
        'loss': lossSumCp,
        'best': best,
        'brilliant': brilliant,
        'inacc': inaccuracies,
        'mist': mistakes,
        'blun': blunders,
        'phase': errorsByPhase,
        'recent': recentAcpl,
      };

  static CoachSession fromJson(Map<String, dynamic> m) {
    int i(String k) => (m[k] is num) ? (m[k] as num).toInt() : 0;

    final s = CoachSession()
      ..games = i('games')
      ..moves = i('moves')
      ..lossSumCp = i('loss')
      ..best = i('best')
      ..brilliant = i('brilliant')
      ..inaccuracies = i('inacc')
      ..mistakes = i('mist')
      ..blunders = i('blun');

    final ph = m['phase'];

    if (ph is Map) {
      for (final k in s.errorsByPhase.keys.toList()) {
        final v = ph[k];

        if (v is num) s.errorsByPhase[k] = v.toInt();
      }
    }

    final r = m['recent'];

    if (r is List) {
      s.recentAcpl.addAll(r.whereType<num>().map((e) => e.toInt()));
    }

    return s;
  }
}

class CoachSessionStore {
  CoachSessionStore._();

  static final CoachSessionStore instance = CoachSessionStore._();

  static const String _key = 'chess2_coach_session';

  CoachSession session = CoachSession();

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;

    _loaded = true;

    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);

      if (raw != null) {
        final v = jsonDecode(raw);

        if (v is Map<String, dynamic>) session = CoachSession.fromJson(v);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();

      await p.setString(_key, jsonEncode(session.toJson()));
    } catch (_) {}
  }

  /// يسجّل مباراة منتهية (نقلات اللاعب فقط).
  Future<void> recordGame(Iterable<MoveAnalysisResult> userMoves) async {
    await load();

    final s = session;

    var gameLoss = 0;
    var n = 0;

    for (final r in userMoves) {
      n++;
      gameLoss += r.evaluationLossCp;

      switch (r.classification) {
        case MoveQuality.best:
        case MoveQuality.great:
          s.best++;
        case MoveQuality.brilliant:
          s.best++;
          s.brilliant++;
        case MoveQuality.inaccuracy:
          s.inaccuracies++;
          _phaseError(r.phase);
        case MoveQuality.mistake:
        case MoveQuality.miss:
          s.mistakes++;
          _phaseError(r.phase);
        case MoveQuality.blunder:
          s.blunders++;
          _phaseError(r.phase);
        default:
          break;
      }
    }

    if (n == 0) return;

    s.games++;
    s.moves += n;
    s.lossSumCp += gameLoss;

    s.recentAcpl.add((gameLoss / n).round());

    while (s.recentAcpl.length > 10) {
      s.recentAcpl.removeAt(0);
    }

    await _save();
  }

  void _phaseError(String phase) {
    final k = session.errorsByPhase.containsKey(phase) ? phase : 'middlegame';

    session.errorsByPhase[k] = (session.errorsByPhase[k] ?? 0) + 1;
  }

  Future<void> reset() async {
    session = CoachSession();

    await _save();
  }

  /// حقائق شخصية قصيرة تُعطى للنموذج وتُعرض كنصيحة المدرب. تُستنتج
  /// بقواعد حتمية من الإحصاءات (لا يخترعها النموذج).
  List<String> insights(CoachLang lang) {
    final s = session;
    final ar = lang == CoachLang.ar;
    final out = <String>[];

    if (s.games < 2 || s.moves < 20) return out;

    final errs = s.totalErrors;

    if (errs >= 6) {
      final op = s.errorsByPhase['opening'] ?? 0;
      final en = s.errorsByPhase['endgame'] ?? 0;

      if (op / errs >= 0.4) {
        out.add(ar
            ? 'معظم أخطائك تقع في الافتتاح؛ ركّز على تطوير القطع '
                'وتأمين الملك أولًا.'
            : 'Most of your errors happen in the opening; focus on '
                'development and king safety first.');
      }

      if (en / errs >= 0.4) {
        out.add(ar
            ? 'أخطاؤك تتركز في النهايات؛ تدرّب على نشاط الملك والبيادق '
                'الحرة.'
            : 'Your errors cluster in endgames; practise king activity '
                'and passed pawns.');
      }
    }

    if (s.moves > 0 && s.blunders / s.moves >= 0.04) {
      out.add(ar
          ? 'تكرر لديك الخطأ الفادح؛ اجعل فحص تهديدات الخصم عادة قبل كل '
              'نقلة.'
          : 'Blunders are frequent; make checking your opponent’s '
              'threats a habit before every move.');
    }

    final r = s.recentAcpl;

    if (r.length >= 4) {
      final half = r.length ~/ 2;

      final older = r.take(half).reduce((a, b) => a + b) / half;
      final newer =
          r.skip(half).reduce((a, b) => a + b) / (r.length - half);

      if (newer < older * 0.85) {
        out.add(ar
            ? 'أداؤك يتحسن: متوسط خسارة النقلة انخفض في مبارياتك '
                'الأخيرة.'
            : 'You are improving: your average loss per move dropped in '
                'recent games.');
      } else if (newer > older * 1.15) {
        out.add(ar
            ? 'تراجع أداؤك قليلًا في المباريات الأخيرة؛ خذ وقتك في '
                'النقلات الحرجة.'
            : 'Your recent games were a bit weaker; take more time on '
                'critical moves.');
      }
    }

    return out;
  }
}
