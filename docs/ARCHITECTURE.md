# بنية المشروع (Chess2)

## نقطة الدخول
- `main.dart` — يحمّل الإعدادات ويشغّل التطبيق فقط.
- `app.dart` — `ChessAnalyzerApp`: الثيم + RTL + الشاشة الرئيسية.
- `app_theme.dart` — الثيم الموحّد (فاتح/داكن) للأزرار والبطاقات والشريط العلوي.

## واجهة مشتركة (`app_ui.dart`)
كل الشاشات تستخدم هذه المكوّنات بدل تكرار الأنماط:
- `AppBoard` — الرقعة الوحيدة المعتمدة في الشاشات؛ تقرأ ثيم الرقعة/القطع من
  `AppSettings` وتستمع لتغييرهما. (`BoardWidget` يبقى المحرّك الداخلي، ويُستعمل
  مباشرة فقط في معاينة الإعدادات.)
- `PuzzleLayout` + `SolutionCard` + `FeedbackText` — هيكل موحّد لشاشتي الألغاز.
- `AppActionBar`, `CenteredPage`, `CenteredMessage`, `LoadingView`.
- `showAppSnack`, `pushScreen` — رسائل وتنقّل موحّدان.
- `AppColors`, `kBoardMaxWidth` — ألوان دلالية وحد عرض الرقعة.

## الشاشات
| الشاشة | الملف |
|---|---|
| الرئيسية | `home_screen.dart` (قائمة بيانات `_MenuEntry`) |
| تحليل وضعية | `position_analyzer_screen.dart` |
| حلل مباراة (مصادر) | `my_games_screen.dart` → `game_source_screen.dart` (Chess.com وLichess بنمط واحد عبر `game_source.dart`) / `pgn_import_screen.dart` |
| تحليل/مراجعة مباراة | `game_analysis_screen.dart` (الحالة والتنقل) + أجزاء `game_analysis_*.dart` |
| العب ضد روبوت / Maia | `bot_play_screen.dart` / `maia_play_screen.dart` |
| تمارين من مبارياتك | `puzzles_screen.dart` (`puzzle_storage.dart`) |
| ألغاز بريليانت / جيك ميت | `lichess_puzzles_screen.dart` (`lichess_puzzles.dart`، بيانات `assets/puzzles/`) |
| الإعدادات | `settings_screen.dart` |

## قاعدة إضافة شاشة جديدة فيها رقعة
1. استخدم `AppBoard` (لا تنشئ `BoardWidget` بثيمات يدوية).
2. للألغاز استخدم `PuzzleLayout`.
3. للرسائل `showAppSnack`، وللتنقل `pushScreen`.

## مصادر المباريات (Chess.com / Lichess)
- `game_source.dart` — واجهة `GameSource` و`SourceGame`؛ لكل مصدر تنفيذ
  (`ChessComSource`, `LichessSource`) يوحّد الحساب المحفوظ والتحقق والجلب
  ورسائل الخطأ.
- `game_source_screen.dart` — الشاشة الوحيدة لكل المصادر (بنمط Chess.com:
  حساب محفوظ، آخر 50 مباراة تلقائيًا، تبديل الحساب).
- `source_style.dart` — الألوان والحقول والأزرار والهيكل المشترك (تستخدمها
  أيضًا شاشة لصق PGN).
- لإضافة مصدر جديد: نفّذ `GameSource` و`SourceGame` فقط، ثم افتح
  `GameSourceScreen(source: ...)` من `my_games_screen.dart`.

## تقسيم شاشة تحليل المباراة
`game_analysis_screen.dart` يحتوي الـ Widget والحالة (الحقول، دورة الحياة،
التنقل، `build`). بقية الدوال في ملفات `part` على شكل extensions على الحالة:
`game_analysis_stats.dart` (حسابات)، `_summary` (التحليل والملخص)،
`_review` (الرقعة والأزرار)، `_report` (الدقة والتقرير)، `_lists`
(النقلات والأخطاء واللحظات الحرجة)، `_widgets` (الرسوم والمكوّنات الصغيرة).
- الاستدعاء بين الأجزاء والحالة يتم مباشرة باسم الدالة (`_name()`).
- داخل الـ extensions استخدم `_update(() {...})` بدل `setState`.
