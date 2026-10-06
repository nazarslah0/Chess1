import 'account_storage.dart';
import 'chesscom_service.dart';
import 'lichess_service.dart';

/// مباراة من أي مصدر بصيغة موحّدة، تكفي شاشة المصدر وشاشة التحليل.
abstract class SourceGame {
  String get pgn;
  String get timeClass;
  DateTime? get endTime;

  String opponentOf(String username);

  /// 'win' أو 'draw' أو 'loss' بالنسبة للاعب [username].
  String outcomeFor(String username);

  String whiteLabel(String username);
  String blackLabel(String username);
  String resultLabel(String username);
}

/// مصدر مباريات (Chess.com / Lichess): يوحّد الحساب المحفوظ والتحقق
/// والجلب ورسائل الخطأ، فتعمل شاشة واحدة لكل المصادر.
abstract class GameSource {
  const GameSource();

  String get name;
  String get usernameHint;

  Future<String?> savedUsername();
  Future<void> saveUsername(String username);
  Future<void> verifyUsername(String username);
  Future<List<SourceGame>> fetchRecentGames(String username, {int limit = 50});

  /// رسالة خطأ مفهومة للمستخدم.
  String errorMessage(Object error);
}

// ============================================================
// Chess.com
// ============================================================

class ChessComSource extends GameSource {
  ChessComSource() : _service = ChessComService();

  final ChessComService _service;

  @override
  String get name => 'Chess.com';

  @override
  String get usernameHint => 'hikaru';

  @override
  Future<String?> savedUsername() => AccountStorage.getChessComUsername();

  @override
  Future<void> saveUsername(String username) =>
      AccountStorage.saveChessComUsername(username);

  @override
  Future<void> verifyUsername(String username) =>
      _service.verifyUsername(username);

  @override
  Future<List<SourceGame>> fetchRecentGames(
    String username, {
    int limit = 50,
  }) async {
    final games = await _service.fetchRecentGames(username, limit: limit);

    return <SourceGame>[for (final g in games) ChessComSourceGame(g)];
  }

  @override
  String errorMessage(Object error) => error is ChessComException
      ? error.message
      : 'حدث خطأ أثناء الاتصال بـ Chess.com.';
}

class ChessComSourceGame implements SourceGame {
  const ChessComSourceGame(this._g);

  final ChessComGame _g;

  bool _isWhite(String username) =>
      _g.whiteUsername.toLowerCase() == username.trim().toLowerCase();

  @override
  String get pgn => _g.pgn;

  @override
  String get timeClass => _g.timeClass;

  @override
  DateTime? get endTime => _g.endTime;

  @override
  String opponentOf(String username) => _g.opponentOf(username);

  @override
  String outcomeFor(String username) => _g.outcomeFor(username);

  @override
  String whiteLabel(String username) =>
      _isWhite(username) ? username : opponentOf(username);

  @override
  String blackLabel(String username) =>
      _isWhite(username) ? opponentOf(username) : username;

  @override
  String resultLabel(String username) =>
      _isWhite(username) ? _g.whiteResult : _g.blackResult;
}

// ============================================================
// Lichess
// ============================================================

class LichessSource extends GameSource {
  LichessSource() : _service = LichessService();

  final LichessService _service;

  @override
  String get name => 'Lichess';

  @override
  String get usernameHint => 'DrNykterstein';

  @override
  Future<String?> savedUsername() => AccountStorage.getLichessUsername();

  @override
  Future<void> saveUsername(String username) =>
      AccountStorage.saveLichessUsername(username);

  @override
  Future<void> verifyUsername(String username) =>
      _service.verifyUsername(username);

  @override
  Future<List<SourceGame>> fetchRecentGames(
    String username, {
    int limit = 50,
  }) async {
    final games = await _service.fetchRecentGames(username, limit: limit);

    return <SourceGame>[for (final g in games) LichessSourceGame(g)];
  }

  @override
  String errorMessage(Object error) => error is LichessException
      ? error.message
      : 'حدث خطأ غير متوقع أثناء الاتصال بـ Lichess.';
}

class LichessSourceGame implements SourceGame {
  const LichessSourceGame(this._g);

  final LichessGame _g;

  @override
  String get pgn => _g.pgn;

  @override
  String get timeClass => _g.timeClass;

  @override
  DateTime? get endTime => _g.endTime;

  @override
  String opponentOf(String username) => _g.opponentOf(username);

  @override
  String outcomeFor(String username) => _g.outcomeFor(username);

  @override
  String whiteLabel(String username) => _g.whiteUsername;

  @override
  String blackLabel(String username) => _g.blackUsername;

  @override
  String resultLabel(String username) => _g.result;
}
