import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translations.dart';

/// اللغات المدعومة: الإنجليزية، العربية، الإسبانية، الفرنسية.
const List<String> kSupportedLanguageCodes = <String>['en', 'ar', 'es', 'fr'];

/// قيمة «تلقائي»: اتّباع لغة الجهاز.
const String kSystemLanguage = 'system';

/// اسم كل لغة بلغتها الأصلية (يظهر في قائمة اختيار اللغة).
const Map<String, String> kLanguageNativeNames = <String, String>{
  'en': 'English',
  'ar': 'العربية',
  'es': 'Español',
  'fr': 'Français',
};

/// يحدّد لغة التطبيق: إما ما اختاره المستخدم، أو لغة الجهاز تلقائيًا.
/// إن كانت لغة الجهاز غير مدعومة نستخدم الإنجليزية.
class LocaleController extends ChangeNotifier {
  LocaleController._();

  static final LocaleController instance = LocaleController._();

  static const String _kKey = 'golden_chess_language';

  /// null = تلقائي (لغة الجهاز).
  String? _override;

  String _active = 'en';

  String? get override => _override;

  /// القيمة المختارة في القائمة: 'system' أو رمز لغة.
  String get selection => _override ?? kSystemLanguage;

  String get languageCode => _active;

  Locale get locale => Locale(_active);

  bool get isRtl => _active == 'ar';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getString(_kKey);

      if (saved != null && kSupportedLanguageCodes.contains(saved)) {
        _override = saved;
      }
    } catch (_) {}

    _active = _resolve();
  }

  String _systemCode() {
    try {
      final locales = WidgetsBinding.instance.platformDispatcher.locales;

      for (final l in locales) {
        if (kSupportedLanguageCodes.contains(l.languageCode)) {
          return l.languageCode;
        }
      }
    } catch (_) {}

    return 'en';
  }

  String _resolve() => _override ?? _systemCode();

  /// يُستدعى عند تغيّر لغة الجهاز أثناء تشغيل التطبيق.
  void onSystemLocalesChanged() {
    if (_override != null) return;

    final next = _resolve();

    if (next == _active) return;

    _active = next;
    notifyListeners();
  }

  /// [code] = 'system' للتلقائي، أو أحد [kSupportedLanguageCodes].
  Future<void> setLanguage(String code) async {
    if (code == kSystemLanguage) {
      _override = null;
    } else if (kSupportedLanguageCodes.contains(code)) {
      _override = code;
    } else {
      return;
    }

    _active = _resolve();
    notifyListeners();

    try {
      final p = await SharedPreferences.getInstance();

      if (_override == null) {
        await p.remove(_kKey);
      } else {
        await p.setString(_kKey, _override!);
      }
    } catch (_) {}
  }
}

/// يترجم نصًّا مكتوبًا بالعربية (المفتاح هو النص العربي نفسه) إلى لغة
/// التطبيق الحالية. إن لم توجد ترجمة يعيد النص العربي كما هو.
///
/// [args] تستبدل العناصر `{name}` داخل النص.
String tr(String ar, [Map<String, Object?>? args]) {
  var s = ar;

  final code = LocaleController.instance.languageCode;

  if (code != 'ar') {
    final entry = kTranslations[ar];

    if (entry != null) {
      final i = code == 'en' ? 0 : (code == 'es' ? 1 : 2);

      if (i < entry.length && entry[i].isNotEmpty) s = entry[i];
    }
  }

  if (args != null) {
    args.forEach((k, v) {
      s = s.replaceAll('{$k}', '$v');
    });
  }

  return s;
}

/// نص مترجم يمكن استخدامه داخل سياقات `const`. يشترك في تغيّر لغة
/// التطبيق فيُعاد بناؤه تلقائيًا عند تبديل اللغة.
class TrText extends StatelessWidget {
  final String ar;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const TrText(
    this.ar, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);

    return Text(
      tr(ar),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}
