import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// معرّف وحدة البانر. الافتراضي معرّف Google التجريبي؛ للإنتاج مرّر
/// --dart-define=ADMOB_BANNER_ID=ca-app-pub-XXXX/YYYY عند البناء
/// (الـworkflow يمرره من سر ADMOB_BANNER_ID).
const String _kBannerId = String.fromEnvironment(
  'ADMOB_BANNER_ID',
  defaultValue: 'ca-app-pub-3940256099942544/6300978111',
);

const String _kInterstitialId = String.fromEnvironment(
  'ADMOB_INTERSTITIAL_ID',
  defaultValue: 'ca-app-pub-3940256099942544/1033173712',
);

const String _kRewardedId = String.fromEnvironment(
  'ADMOB_REWARDED_ID',
  defaultValue: 'ca-app-pub-3940256099942544/5224354917',
);

const String _kAppOpenId = String.fromEnvironment(
  'ADMOB_APPOPEN_ID',
  defaultValue: 'ca-app-pub-3940256099942544/9257395921',
);

/// أقل فاصل بين إعلانين بينيين (حماية للمستخدم وللحساب من الإزعاج).
const Duration _kInterstitialCooldown = Duration(seconds: 60);

/// يدير موافقة المستخدم (UMP) ثم تهيئة AdMob. لا تُطلب إعلانات قبل
/// الموافقة (مطلوب في الاتحاد الأوروبي وبريطانيا).
class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();

  /// true عندما يُسمح بطلب الإعلانات (بعد الموافقة والتهيئة).
  final ValueNotifier<bool> adsReady = ValueNotifier<bool>(false);

  /// true إن كان يجب إتاحة زر «خيارات الخصوصية» للمستخدم.
  final ValueNotifier<bool> privacyOptionsRequired =
      ValueNotifier<bool>(false);

  bool _started = false;

  final DateTime _startedAt = DateTime.now();

  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;
  DateTime? _lastInterstitial;

  RewardedAd? _rewarded;
  bool _loadingRewarded = false;

  bool _appOpenTried = false;

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  Future<void> init() async {
    if (_started || !_supported) return;

    _started = true;

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired(
            (FormError? formError) {
              _refresh();
            },
          );
        },
        (FormError error) {
          // حتى لو فشل التحديث قد تكون الموافقة محفوظة من قبل.
          _refresh();
        },
      );
    } catch (_) {}
  }

  Future<void> showPrivacyOptions() async {
    if (!_supported) return;

    try {
      await ConsentForm.showPrivacyOptionsForm(
        (FormError? formError) {
          _refresh();
        },
      );
    } catch (_) {}
  }

  Future<void> _refresh() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();

      privacyOptionsRequired.value =
          status == PrivacyOptionsRequirementStatus.required;

      final canRequest = await ConsentInformation.instance.canRequestAds();

      if (canRequest) {
        await MobileAds.instance.initialize();
      }

      adsReady.value = canRequest;

      if (canRequest) {
        _loadAppOpen();
        _loadInterstitial();
        _loadRewarded();
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // إعلان فتح التطبيق: يُعرض مرة عند بدء التشغيل إن جاهز خلال ثوانٍ.
  // ------------------------------------------------------------

  void _loadAppOpen() {
    if (_appOpenTried) return;

    _appOpenTried = true;

    AppOpenAd.load(
      adUnitId: _kAppOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (AppOpenAd ad) {
          // تأخر التحميل: لا نقاطع المستخدم وهو يستخدم التطبيق.
          if (DateTime.now().difference(_startedAt) >
              const Duration(seconds: 8)) {
            ad.dispose();
            return;
          }

          ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
            onAdDismissedFullScreenContent: (AppOpenAd a) => a.dispose(),
            onAdFailedToShowFullScreenContent:
                (AppOpenAd a, AdError error) => a.dispose(),
          );

          unawaited(ad.show());
        },
        onAdFailedToLoad: (LoadAdError error) {},
      ),
    );
  }

  // ------------------------------------------------------------
  // الإعلان البيني
  // ------------------------------------------------------------

  void _loadInterstitial() {
    if (!adsReady.value || _interstitial != null || _loadingInterstitial) {
      return;
    }

    _loadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: _kInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _loadingInterstitial = false;
        },
      ),
    );
  }

  /// يعرض إعلانًا بينيًا إن كان جاهزًا ومرّ الفاصل الأدنى، ويكتمل
  /// عند إغلاقه (أو فورًا إن لم يُعرض شيء). لا يحجب المستخدم أبدًا.
  Future<void> showInterstitial() async {
    final ad = _interstitial;

    if (!_supported || !adsReady.value || ad == null) {
      _loadInterstitial();

      return;
    }

    final last = _lastInterstitial;

    if (last != null &&
        DateTime.now().difference(last) < _kInterstitialCooldown) {
      return;
    }

    _interstitial = null;

    final done = Completer<void>();

    void finish(InterstitialAd a) {
      a.dispose();
      _loadInterstitial();

      if (!done.isCompleted) done.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (InterstitialAd a) {
        _lastInterstitial = DateTime.now();
      },
      onAdDismissedFullScreenContent: finish,
      onAdFailedToShowFullScreenContent:
          (InterstitialAd a, AdError error) => finish(a),
    );

    try {
      await ad.show();
    } catch (_) {
      finish(ad);
    }

    await done.future;
  }

  // ------------------------------------------------------------
  // الإعلان المكافئ
  // ------------------------------------------------------------

  void _loadRewarded() {
    if (!adsReady.value || _rewarded != null || _loadingRewarded) return;

    _loadingRewarded = true;

    RewardedAd.load(
      adUnitId: _kRewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _loadingRewarded = false;
        },
      ),
    );
  }

  /// يعرض إعلانًا مكافئًا ويعيد true إن استحق المستخدم المكافأة.
  /// إن تعذّر توفّر إعلان (لا إنترنت/لا موافقة/لا إعلان متاح) يعيد true
  /// كي لا يُحجب المستخدم عن الميزة بسبب مشكلة في الإعلانات.
  Future<bool> showRewarded() async {
    if (!_supported || !adsReady.value) return true;

    if (_rewarded == null) {
      _loadRewarded();

      // انتظار قصير لتحميل الإعلان.
      for (var i = 0; i < 20 && _rewarded == null && _loadingRewarded; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }

    final ad = _rewarded;

    if (ad == null) return true;

    _rewarded = null;

    var earned = false;

    final done = Completer<void>();

    void finish(RewardedAd a) {
      a.dispose();
      _loadRewarded();

      if (!done.isCompleted) done.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: finish,
      onAdFailedToShowFullScreenContent:
          (RewardedAd a, AdError error) {
        // فشل العرض لا يعاقب المستخدم.
        earned = true;
        finish(a);
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (AdWithoutView view, RewardItem reward) {
          earned = true;
        },
      );
    } catch (_) {
      earned = true;
      finish(ad);
    }

    await done.future;

    return earned;
  }
}

/// بانر إعلاني صغير. يختفي كليًا ما لم تتوفر موافقة وإعلان جاهز.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  Timer? _retry;

  @override
  void initState() {
    super.initState();

    AdsService.instance.adsReady.addListener(_sync);

    _sync();
  }

  @override
  void dispose() {
    AdsService.instance.adsReady.removeListener(_sync);
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;

    if (!AdsService.instance.adsReady.value) {
      // سُحبت الموافقة أو لم تتوفر بعد: لا إعلان.
      if (_ad != null) {
        _ad!.dispose();

        setState(() {
          _ad = null;
          _loaded = false;
        });
      }

      return;
    }

    if (_ad != null) return;

    final ad = BannerAd(
      adUnitId: _kBannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad loadedAd) {
          if (!mounted) {
            loadedAd.dispose();
            return;
          }

          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (Ad failedAd, LoadAdError error) {
          failedAd.dispose();

          if (!mounted) return;

          setState(() {
            _ad = null;
            _loaded = false;
          });

          // يبقى البانر دائمًا: نعيد المحاولة بعد قليل.
          _retry?.cancel();
          _retry = Timer(const Duration(seconds: 30), _sync);
        },
      ),
    );

    _ad = ad;

    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;

    if (ad == null || !_loaded) return const SizedBox.shrink();

    return Center(
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
