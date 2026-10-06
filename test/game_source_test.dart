import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_analyzer/account_storage.dart';
import 'package:chess_analyzer/chesscom_service.dart';
import 'package:chess_analyzer/game_source.dart';
import 'package:chess_analyzer/game_source_screen.dart';
import 'package:chess_analyzer/lichess_service.dart';

class _FakeGame implements SourceGame {
  const _FakeGame(this._opponent, this._outcome);

  final String _opponent;
  final String _outcome;

  @override
  String get pgn => '1. e4 e5';

  @override
  String get timeClass => 'blitz';

  @override
  DateTime? get endTime => DateTime(2026, 10, 5);

  @override
  String opponentOf(String username) => _opponent;

  @override
  String outcomeFor(String username) => _outcome;

  @override
  String whiteLabel(String username) => username;

  @override
  String blackLabel(String username) => _opponent;

  @override
  String resultLabel(String username) => '1-0';
}

class _FakeSource extends GameSource {
  _FakeSource({this.saved});

  String? saved;
  final List<String> verified = <String>[];

  @override
  String get name => 'Fake';

  @override
  String get usernameHint => 'someone';

  @override
  Future<String?> savedUsername() async => saved;

  @override
  Future<void> saveUsername(String username) async => saved = username;

  @override
  Future<void> verifyUsername(String username) async =>
      verified.add(username);

  @override
  Future<List<SourceGame>> fetchRecentGames(
    String username, {
    int limit = 50,
  }) async =>
      const <SourceGame>[
        _FakeGame('Bob', 'win'),
        _FakeGame('Carl', 'loss'),
        _FakeGame('Dina', 'draw'),
      ];

  @override
  String errorMessage(Object error) => 'خطأ';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChessComSourceGame', () {
    const game = ChessComGame(
      pgn: '1. e4 e5',
      whiteUsername: 'Alice',
      blackUsername: 'bob',
      whiteResult: 'win',
      blackResult: 'resigned',
      timeClass: 'blitz',
    );

    test('اللاعب الأبيض', () {
      const g = ChessComSourceGame(game);

      expect(g.opponentOf('alice'), 'bob');
      expect(g.outcomeFor('alice'), 'win');
      expect(g.whiteLabel('alice'), 'alice');
      expect(g.blackLabel('alice'), 'bob');
      expect(g.resultLabel('alice'), 'win');
    });

    test('اللاعب الأسود يحتفظ بما كتبه المستخدم', () {
      const g = ChessComSourceGame(game);

      expect(g.opponentOf('BOB'), 'Alice');
      expect(g.outcomeFor('BOB'), 'loss');
      expect(g.whiteLabel('BOB'), 'Alice');
      expect(g.blackLabel('BOB'), 'BOB');
      expect(g.resultLabel('BOB'), 'resigned');
    });
  });

  group('LichessSourceGame', () {
    const game = LichessGame(
      pgn: '1. e4 e5',
      whiteUsername: 'Alice',
      blackUsername: 'Bob',
      result: '1-0',
    );

    test('النتيجة والتسميات من المباراة نفسها', () {
      const g = LichessSourceGame(game);

      expect(g.outcomeFor('alice'), 'win');
      expect(g.outcomeFor('bob'), 'loss');
      expect(g.opponentOf('alice'), 'Bob');
      expect(g.whiteLabel('bob'), 'Alice');
      expect(g.blackLabel('bob'), 'Bob');
      expect(g.resultLabel('bob'), '1-0');
    });
  });

  group('AccountStorage', () {
    test('حسابا Chess.com وLichess منفصلان', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      expect(await AccountStorage.getChessComUsername(), isNull);
      expect(await AccountStorage.getLichessUsername(), isNull);

      await AccountStorage.saveChessComUsername('  hikaru ');
      await AccountStorage.saveLichessUsername('DrNykterstein');

      expect(await AccountStorage.getChessComUsername(), 'hikaru');
      expect(await AccountStorage.getLichessUsername(), 'DrNykterstein');
    });
  });

  group('GameSourceScreen', () {
    testWidgets('يحمّل الحساب المحفوظ ويعرض المباريات بنمط موحّد', (
      tester,
    ) async {
      final source = _FakeSource(saved: 'ali');

      await tester.pumpWidget(MaterialApp(home: GameSourceScreen(source: source)));
      await tester.pumpAndSettle();

      expect(find.text('تحليل مباريات Fake'), findsOneWidget);
      expect(find.text('ali'), findsWidgets);
      expect(source.verified, <String>['ali']);
      expect(find.text('آخر 50 مباراة'), findsOneWidget);
      expect(find.text('ضد Bob'), findsOneWidget);
      expect(find.text('ضد Carl'), findsOneWidget);
      expect(find.text('فوز'), findsOneWidget);
      expect(find.text('خسارة'), findsOneWidget);
      expect(find.text('تعادل'), findsOneWidget);
    });

    testWidgets('بلا حساب محفوظ: رسالة إرشادية بلا بحث', (tester) async {
      final source = _FakeSource();

      await tester.pumpWidget(MaterialApp(home: GameSourceScreen(source: source)));
      await tester.pumpAndSettle();

      expect(source.verified, isEmpty);
      expect(find.text('لم يتم اختيار حساب'), findsOneWidget);
      expect(find.textContaining('أدخل اسم حسابك على Fake'), findsOneWidget);
    });
  });
}
