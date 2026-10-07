import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// إعدادات التطبيق العامة. أي شاشة فيها رقعة (تحليل وضعية، تحليل
/// مباراة، اللعب ضد Maia، التمارين...) تقرأ الثيمات من هنا، فتغييرها
/// في الإعدادات ينعكس على كل الرقع.
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  /// الثيمات المتاحة: مظهر Chess.com أولًا (الافتراضي)، ثم بقية
  /// الثيمات.
  static final List<BoardTheme> allBoardThemes = <BoardTheme>[
    chessComBoardTheme,
    ...boardThemes,
  ];

  static final List<PieceTheme> allPieceThemes = <PieceTheme>[
    chessComPieceTheme,
    ...pieceThemes,
  ];

  static const String _kBoard = 'chess2_board_theme';
  static const String _kPiece = 'chess2_piece_theme';
  static const String _kMaia = 'chess2_maia_bucket';
  static const String _kName = 'chess2_player_name';

  // ---- التدريب الذكي أثناء المباراة ----
  static const String _kTrOn = 'chess2_tr_on';
  static const String _kTrFeedback = 'chess2_tr_feedback';
  static const String _kTrArrow = 'chess2_tr_arrow';
  static const String _kTrBest = 'chess2_tr_allow_best';
  static const String _kTrAuto = 'chess2_tr_auto';
  static const String _kTrDelay = 'chess2_tr_delay';
  static const String _kTrMinLoss = 'chess2_tr_min_loss';
  static const String _kTrSound = 'chess2_tr_sound';
  static const String _kTrHaptic = 'chess2_tr_haptic';

  bool _trOn = true;
  bool _trFeedback = true;
  bool _trArrow = true;
  bool _trAllowBest = true;
  bool _trAuto = true;
  int _trDelaySec = 2;
  int _trMinLossCp = 50;
  bool _trSound = true;
  bool _trHaptic = true;

  /// القيم المسموحة لحد الخسارة الأدنى (سنتيبون) وزمن الـFeedback.
  static const List<int> trainingMinLossOptions = <int>[20, 50, 80, 100];
  static const List<int> trainingDelayOptions = <int>[1, 2, 3];

  /// تشغيل «التدريب الذكي أثناء المباراة» (يظهر أيضًا كمفتاح
  /// «تحليل أثناء اللعب» في شاشة العب ضد روبوت).
  bool get smartTraining => _trOn;
  bool get trainingFeedback => _trFeedback;
  bool get trainingHintArrow => _trArrow;
  bool get trainingAllowBestMove => _trAllowBest;
  bool get trainingAutoAnalysis => _trAuto;
  int get trainingFeedbackDelaySec => _trDelaySec;

  /// أقل خسارة تقييم (بالسنتيبون) تستحق رسالة «هناك نقلة أقوى».
  int get trainingMinLossCp => _trMinLossCp;
  bool get trainingSound => _trSound;
  bool get trainingHaptic => _trHaptic;

  // ---- المدرب المحلي (Local AI Chess Coach) ----
  static const String _kCoachLevel = 'chess2_coach_level';
  static const String _kCoachLang = 'chess2_coach_lang';
  static const String _kCoachModel = 'chess2_coach_use_model';
  static const String _kCoachAll = 'chess2_coach_explain_all';

  String _coachLevel = 'intermediate';
  String _coachLang = 'ar';
  bool _coachUseModel = true;
  bool _coachExplainAll = false;

  /// beginner / intermediate / advanced / expert.
  String get coachLevelName => _coachLevel;

  /// ar / en.
  String get coachLangName => _coachLang;

  /// استخدام النموذج اللغوي المحلي (إن كان مثبّتًا)؛ وإلا قوالب فقط.
  bool get coachUseModel => _coachUseModel;

  /// شرح كل النقلات بالنموذج (افتراضيًا: النقلات الصعبة فقط).
  bool get coachExplainAll => _coachExplainAll;

  int _boardIdx = 0;
  int _pieceIdx = 0;
  int _maiaBucket = 1500;
  String _playerName = '';

  int get boardThemeIndex => _boardIdx;
  int get pieceThemeIndex => _pieceIdx;

  BoardTheme get boardTheme => allBoardThemes[_boardIdx];
  PieceTheme get pieceTheme => allPieceThemes[_pieceIdx];

  /// مستوى Maia الافتراضي (1100 / 1500 / 1900).
  int get maiaBucket => _maiaBucket;

  /// اسم المستخدم في المباريات (Chess.com / Lichess)، لمعرفة أي
  /// لاعب هو أنت عند استخراج التمارين وتقييم الأداء.
  String get playerName => _playerName;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();

      final b = p.getInt(_kBoard) ?? 0;
      final pc = p.getInt(_kPiece) ?? 0;

      _boardIdx = (b >= 0 && b < allBoardThemes.length) ? b : 0;
      _pieceIdx = (pc >= 0 && pc < allPieceThemes.length) ? pc : 0;
      _maiaBucket = p.getInt(_kMaia) ?? 1500;
      _playerName = p.getString(_kName) ?? '';

      _coachLevel = p.getString(_kCoachLevel) ?? 'intermediate';
      _coachLang = p.getString(_kCoachLang) ?? 'ar';
      _coachUseModel = p.getBool(_kCoachModel) ?? true;
      _coachExplainAll = p.getBool(_kCoachAll) ?? false;

      _trOn = p.getBool(_kTrOn) ?? true;
      _trFeedback = p.getBool(_kTrFeedback) ?? true;
      _trArrow = p.getBool(_kTrArrow) ?? true;
      _trAllowBest = p.getBool(_kTrBest) ?? true;
      _trAuto = p.getBool(_kTrAuto) ?? true;

      final d = p.getInt(_kTrDelay) ?? 2;
      final m = p.getInt(_kTrMinLoss) ?? 50;

      _trDelaySec = trainingDelayOptions.contains(d) ? d : 2;
      _trMinLossCp = trainingMinLossOptions.contains(m) ? m : 50;
      _trSound = p.getBool(_kTrSound) ?? true;
      _trHaptic = p.getBool(_kTrHaptic) ?? true;

      notifyListeners();
    } catch (_) {}
  }

  Future<void> setBoardTheme(int i) async {
    if (i < 0 || i >= allBoardThemes.length) return;

    _boardIdx = i;
    notifyListeners();

    try {
      (await SharedPreferences.getInstance()).setInt(_kBoard, i);
    } catch (_) {}
  }

  Future<void> setPieceTheme(int i) async {
    if (i < 0 || i >= allPieceThemes.length) return;

    _pieceIdx = i;
    notifyListeners();

    try {
      (await SharedPreferences.getInstance()).setInt(_kPiece, i);
    } catch (_) {}
  }

  Future<void> setMaiaBucket(int b) async {
    _maiaBucket = b;
    notifyListeners();

    try {
      (await SharedPreferences.getInstance()).setInt(_kMaia, b);
    } catch (_) {}
  }

  Future<void> setPlayerName(String name) async {
    _playerName = name.trim();
    notifyListeners();

    try {
      (await SharedPreferences.getInstance())
          .setString(_kName, _playerName);
    } catch (_) {}
  }

  Future<void> _saveBool(String key, bool v) async {
    try {
      (await SharedPreferences.getInstance()).setBool(key, v);
    } catch (_) {}
  }

  Future<void> _saveInt(String key, int v) async {
    try {
      (await SharedPreferences.getInstance()).setInt(key, v);
    } catch (_) {}
  }

  Future<void> setCoachLevel(String name) async {
    _coachLevel = name;
    notifyListeners();

    try {
      (await SharedPreferences.getInstance())
          .setString(_kCoachLevel, name);
    } catch (_) {}
  }

  Future<void> setCoachLang(String name) async {
    _coachLang = name == 'en' ? 'en' : 'ar';
    notifyListeners();

    try {
      (await SharedPreferences.getInstance())
          .setString(_kCoachLang, _coachLang);
    } catch (_) {}
  }

  Future<void> setCoachUseModel(bool v) async {
    _coachUseModel = v;
    notifyListeners();
    await _saveBool(_kCoachModel, v);
  }

  Future<void> setCoachExplainAll(bool v) async {
    _coachExplainAll = v;
    notifyListeners();
    await _saveBool(_kCoachAll, v);
  }

  Future<void> setSmartTraining(bool v) async {
    _trOn = v;
    notifyListeners();
    await _saveBool(_kTrOn, v);
  }

  Future<void> setTrainingFeedback(bool v) async {
    _trFeedback = v;
    notifyListeners();
    await _saveBool(_kTrFeedback, v);
  }

  Future<void> setTrainingHintArrow(bool v) async {
    _trArrow = v;
    notifyListeners();
    await _saveBool(_kTrArrow, v);
  }

  Future<void> setTrainingAllowBestMove(bool v) async {
    _trAllowBest = v;
    notifyListeners();
    await _saveBool(_kTrBest, v);
  }

  Future<void> setTrainingAutoAnalysis(bool v) async {
    _trAuto = v;
    notifyListeners();
    await _saveBool(_kTrAuto, v);
  }

  Future<void> setTrainingFeedbackDelaySec(int sec) async {
    if (!trainingDelayOptions.contains(sec)) return;

    _trDelaySec = sec;
    notifyListeners();
    await _saveInt(_kTrDelay, sec);
  }

  Future<void> setTrainingMinLossCp(int cp) async {
    if (!trainingMinLossOptions.contains(cp)) return;

    _trMinLossCp = cp;
    notifyListeners();
    await _saveInt(_kTrMinLoss, cp);
  }

  Future<void> setTrainingSound(bool v) async {
    _trSound = v;
    notifyListeners();
    await _saveBool(_kTrSound, v);
  }

  Future<void> setTrainingHaptic(bool v) async {
    _trHaptic = v;
    notifyListeners();
    await _saveBool(_kTrHaptic, v);
  }

  /// هل [name] (من ترويسة PGN) هو اسم المستخدم؟
  bool isMe(String? name) =>
      _playerName.isNotEmpty &&
      name != null &&
      name.trim().toLowerCase() == _playerName.toLowerCase();
}
