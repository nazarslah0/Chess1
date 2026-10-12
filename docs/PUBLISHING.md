# نشر Golden Chess على Google Play

الحزمة: `com.Goldenchess.chess` (لا يمكن تغييرها بعد أول رفع).

## 1) قبل أي شيء
- أنشئ حساب Play Console. الحسابات الشخصية الجديدة تحتاج **12 مختبرًا لمدة 14 يومًا** قبل الإنتاج.
- أنشئ حساب AdMob، وسجّل التطبيق، وأنشئ وحدة Banner.
- انشر سياسة الخصوصية (انظر `PRIVACY_POLICY_DRAFT.md`) على رابط عام، وعدّل `kPrivacyPolicyUrl` في `lib/about_screen.dart`.

## 2) مفتاح التوقيع (مرة واحدة)
```
keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```
احتفظ بالملف وكلمات المرور في مكان آمن (لا ترفعه إلى GitHub). ثم أضف في GitHub → Settings → Secrets:
راجع أسماء الأسرار في `.github/workflows/build.yml` (خطوة Signing).

## 3) AdMob
- أنشئ في AdMob خمس عناصر وضعها كأسرار GitHub (الافتراضي: معرّفات اختبار Google، ولا تضغط على إعلانات حقيقية أثناء التطوير):
  - `ADMOB_APP_ID` (معرّف التطبيق ~)
  - `ADMOB_BANNER_ID` (بانر)
  - `ADMOB_INTERSTITIAL_ID` (بيني)
  - `ADMOB_REWARDED_ID` (مكافئ)
  - `ADMOB_APPOPEN_ID` (فتح التطبيق)
- مواضع الإعلانات: فتح التطبيق عند التشغيل؛ بانر في الرئيسية وشاشة التحليل/انتظار التحليل وكل شاشات الألغاز؛ مكافئ قبل Deep Analysis (PRO)؛ بيني عند «التالي» في الألغاز وبعد حل لغز وبعد نهاية مباراة الروبوت (بفاصل دقيقة بين البينيين).

## 4) البناء
- ادفع وسمًا `v1.0.0` أو شغّل الـ workflow يدويًا → ينتج APK و **AAB** (الذي يُرفع إلى Play).
- يتحقق الـ workflow من محاذاة 16 KB ومن اسم الحزمة.

## 5) Play Console
- Data safety: الإعلانات تجمع Advertising ID وبيانات الجهاز (عبر AdMob).
- تصنيف المحتوى، الفئة المستهدفة (ليس للأطفال)، إقرار الإعلانات = نعم.
- Stockfish مرخّص GPL-3.0: الإشعار ورابط المصدر موجودان في «حول التطبيق».

## 6) ملاحظات
- نسخة الويب (GitHub Pages) لا تعرض إعلانات وتعمل كما كانت.
- قطع `classic_svg` وصور الرقع `boards_svg`: تأكد أنك تملك حقوقها أو أنها بترخيص يسمح بالاستخدام التجاري.
