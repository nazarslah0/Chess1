import 'package:shared_preferences/shared_preferences.dart';

/// حفظ حسابات المصادر (Chess.com / Lichess) التي اختارها المستخدم حتى
/// لا يضطر لإعادة كتابة اسم المستخدم عند كل فتح للشاشة.
class AccountStorage {
  AccountStorage._();

  static const _chessComUsernameKey = 'chesscom_saved_username';
  static const _lichessUsernameKey = 'lichess_saved_username';

  static Future<String?> _read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key)?.trim();

    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> _write(String key, String username) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(key, username.trim());
  }

  static Future<String?> getChessComUsername() =>
      _read(_chessComUsernameKey);

  static Future<void> saveChessComUsername(String username) =>
      _write(_chessComUsernameKey, username);

  static Future<String?> getLichessUsername() => _read(_lichessUsernameKey);

  static Future<void> saveLichessUsername(String username) =>
      _write(_lichessUsernameKey, username);
}
