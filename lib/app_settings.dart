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
  static const String _kSmartTraining = 'chess2_smart_training';
  static const String _kTrainingFeedback = 'chess2_training_feedback';
  static const String _kShowHintArrow = 'chess2_show_hint_arrow';
  static const String _kAllowBestMove = 'chess2_allow_best_move';
  static const String _kAutoAnalysis = 'chess2_auto_analysis';
  static const String _kFeedbackDelayMs = 'chess2_feedback_delay_ms';
  static const String _kMinEvalLossCp = 'chess2_min_eval_loss_cp';
  static const String _kTrainingSound = 'chess2_training_sound';
  static const String _kTrainingHaptic = 'chess2_training_haptic';

  int _boardIdx = 0;
  int _pieceIdx = 0;
  int _maiaBucket = 1500;
  String _playerName = '';

  bool _smartTraining = true;
  bool _trainingFeedback = true;
  bool _showHintArrow = true;
  bool _allowBestMove = true;
  bool _autoAnalysis = true;
  int _feedbackDelayMs = 2000;
  int _minEvalLossCp = 50;
  bool _trainingSound = true;
  bool _trainingHaptic = true;

  int get boardThemeIndex => _boardIdx;
  int get pieceThemeIndex => _pieceIdx;

  BoardTheme get boardTheme => allBoardThemes[_boardIdx];
  PieceTheme get pieceTheme => allPieceThemes[_pieceIdx];

  /// مستوى Maia الافتراضي (1100 / 1500 / 1900).
  int get maiaBucket => _maiaBucket;

  /// اسم المستخدم في المباريات (Chess.com / Lichess)، لمعرفة أي
  /// لاعب هو أنت عند استخراج التمارين وتقييم الأداء.
  String get playerName => _playerName;

  bool get smartTraining => _smartTraining;
  bool get trainingFeedback => _trainingFeedback;
  bool get showHintArrow => _showHintArrow;
  bool get allowBestMove => _allowBestMove;
  bool get autoAnalysis => _autoAnalysis;
  int get feedbackDelayMs => _feedbackDelayMs;
  int get minEvalLossCp => _minEvalLossCp;
  bool get trainingSound => _trainingSound;
  bool get trainingHaptic => _trainingHaptic;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();

      final b = p.getInt(_kBoard) ?? 0;
      final pc = p.getInt(_kPiece) ?? 0;

      _boardIdx = (b >= 0 && b < allBoardThemes.length) ? b : 0;
      _pieceIdx = (pc >= 0 && pc < allPieceThemes.length) ? pc : 0;
      _maiaBucket = p.getInt(_kMaia) ?? 1500;
      _playerName = p.getString(_kName) ?? '';

      _smartTraining = p.getBool(_kSmartTraining) ?? true;
      _trainingFeedback = p.getBool(_kTrainingFeedback) ?? true;
      _showHintArrow = p.getBool(_kShowHintArrow) ?? true;
      _allowBestMove = p.getBool(_kAllowBestMove) ?? true;
      _autoAnalysis = p.getBool(_kAutoAnalysis) ?? true;
      _feedbackDelayMs = p.getInt(_kFeedbackDelayMs) ?? 2000;
      _minEvalLossCp = p.getInt(_kMinEvalLossCp) ?? 50;
      _trainingSound = p.getBool(_kTrainingSound) ?? true;
      _trainingHaptic = p.getBool(_kTrainingHaptic) ?? true;

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


  Future<void> _setBool(String key, bool value, void Function() apply) async {
    apply();
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool(key, value);
    } catch (_) {}
  }

  Future<void> setSmartTraining(bool v) =>
      _setBool(_kSmartTraining, v, () => _smartTraining = v);

  Future<void> setTrainingFeedback(bool v) =>
      _setBool(_kTrainingFeedback, v, () => _trainingFeedback = v);

  Future<void> setShowHintArrow(bool v) =>
      _setBool(_kShowHintArrow, v, () => _showHintArrow = v);

  Future<void> setAllowBestMove(bool v) =>
      _setBool(_kAllowBestMove, v, () => _allowBestMove = v);

  Future<void> setAutoAnalysis(bool v) =>
      _setBool(_kAutoAnalysis, v, () => _autoAnalysis = v);

  Future<void> setTrainingSound(bool v) =>
      _setBool(_kTrainingSound, v, () => _trainingSound = v);

  Future<void> setTrainingHaptic(bool v) =>
      _setBool(_kTrainingHaptic, v, () => _trainingHaptic = v);

  Future<void> setFeedbackDelayMs(int value) async {
    _feedbackDelayMs = value.clamp(1000, 3000).toInt();
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance())
          .setInt(_kFeedbackDelayMs, _feedbackDelayMs);
    } catch (_) {}
  }

  Future<void> setMinEvalLossCp(int value) async {
    _minEvalLossCp = value.clamp(20, 100).toInt();
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance())
          .setInt(_kMinEvalLossCp, _minEvalLossCp);
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

  /// هل [name] (من ترويسة PGN) هو اسم المستخدم؟
  bool isMe(String? name) =>
      _playerName.isNotEmpty &&
      name != null &&
      name.trim().toLowerCase() == _playerName.toLowerCase();
}
