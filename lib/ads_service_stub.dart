import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// نسخة الويب: لا إعلانات.
class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();

  final ValueNotifier<bool> adsReady = ValueNotifier<bool>(false);
  final ValueNotifier<bool> privacyOptionsRequired =
      ValueNotifier<bool>(false);

  Future<void> init() async {}

  Future<void> showPrivacyOptions() async {}

  Future<void> showInterstitial() async {}

  Future<bool> showRewarded() async => true;
}

class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
