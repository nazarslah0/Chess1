// خدمة الإعلانات (AdMob). مكتبة google_mobile_ads تعمل على Android/iOS
// فقط، لذا على الويب (dart.library.io غير متاحة) نستخدم نسخة خاملة لا
// تعرض شيئًا ولا تستورد المكتبة أصلًا، فتبقى نسخة الويب تعمل كما هي.
export 'ads_service_stub.dart'
    if (dart.library.io) 'ads_service_io.dart';
