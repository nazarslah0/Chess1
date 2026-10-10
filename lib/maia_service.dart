import 'package:flutter/services.dart';

// MaiaSession تعتمد على dart:ffi / dart:io (غير متاحة على الويب).
// على Android/iOS/سطح المكتب نستخدم التنفيذ الحقيقي، وعلى الويب نسخة
// خاملة تعيد null فيتخطى المستدعي Maia بصمت (نفس سلوك فشل التحميل).
export 'maia_session_stub.dart'
    if (dart.library.io) 'maia_session_io.dart';

// ================================================================
// Maia: شبكات عصبية تتنبأ بما يلعبه البشر حسب التصنيف.
//
// لا نستخدمها للبحث: تمريرة واحدة (go nodes 1) تعطي احتمال كل نقلة
// قانونية عند لاعب بذلك التصنيف. تُشغَّل عبر حزمة lc0 (Dart FFI) على
// المعالج فقط. أي فشل (ملف أوزان ناقص، تعذّر تشغيل المحرك...) يعيد
// null ويتخطى المستدعي Maia بصمت.
//
// الأوزان تُوضع في assets/maia/ (انظر README.txt هناك).
// ================================================================

class MaiaService {
  MaiaService._();

  /// المستويات المضمّنة. أي تصنيف يُقرَّب لأقربها.
  static const List<int> buckets = <int>[1100, 1500, 1900];

  /// النقلة الأفضل تُرفع إلى "رائعة" إذا وجدها أقل من هذه النسبة من
  /// اللاعبين بتصنيف اللاعب (0.10 = 10%).
  static const double greatMaxProb = 0.10;

  /// وكان تفوقها على ثاني أفضل نقلة (باحتمال الفوز %) لا يقل عن هذا،
  /// كي لا تُرفع نقلة لمجرد أنها واحدة من عدة بدائل متكافئة.
  static const double greatMinGapWinPct = 7;

  static int bucketForElo(int? elo) {
    if (elo == null || elo <= 0) return 1500;

    var best = buckets.first;

    for (final b in buckets) {
      if ((b - elo).abs() < (best - elo).abs()) best = b;
    }

    return best;
  }

  static String assetPath(int bucket) =>
      'assets/maia/maia-$bucket.pb.gz';

  /// المستويات التي أوزانها مضمَّنة فعلًا في التطبيق.
  static Future<List<int>> availableBuckets() async {
    try {
      final manifest =
          await AssetManifest.loadFromAssetBundle(rootBundle);

      final assets = manifest.listAssets().toSet();

      return <int>[
        for (final b in buckets)
          if (assets.contains(assetPath(b))) b,
      ];
    } catch (_) {
      return const <int>[];
    }
  }

  /// أقرب مستوى متاح إلى [wanted] (أو null إن لم يتوفر أي وزن).
  static int? nearestAvailable(int wanted, List<int> available) {
    if (available.isEmpty) return null;

    var best = available.first;

    for (final b in available) {
      if ((b - wanted).abs() < (best - wanted).abs()) best = b;
    }

    return best;
  }

  /// ترتيب نقلات السياسة من الأرجح إلى الأقل.
  static List<MapEntry<String, double>> ranked(
    Map<String, double> policy,
  ) {
    final list = policy.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return list;
  }
}
