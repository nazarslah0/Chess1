# Local AI Chess Coach

Stockfish يحسب — النموذج اللغوي المحلي يشرح فقط. لا API، لا Cloud، لا
Server، ولا إرسال بيانات. الإنترنت مطلوب **مرة واحدة فقط** لتنزيل ملف
النموذج (~1.1 GB) من شاشة AI Coach.

## التدفق

نقلة اللاعب → Stockfish (`training_coach.dart`) → `MoveAnalysisResult`
→ `LocalCoachService` → (قالب فوري) ثم (نموذج محلي للنقلات الصعبة)
→ `CoachExplanation` → بطاقة المدرب في `BotPlayScreen`.

| الملف | الدور |
|---|---|
| `coach_models.dart` | `CoachExplanation`, `CoachMoveInput`, `PositionAnalysis`, المستوى/اللغة |
| `coach_templates.dart` | `CoachTemplateEngine` (Fallback + النقلات السهلة) |
| `coach_prompts.dart` | `CoachPromptEngine` (Prompt + JSON + حاجز «لا تخترع نقلات») |
| `coach_llm.dart` | `LocalCoachModel` (الواجهة القابلة للاستبدال) + `LlamaCppCoachModel` + تنزيل النموذج |
| `local_coach_service.dart` | `LocalCoachService` (تحميل كسول، تحرير عند الخمول، توجيه قالب/نموذج) |
| `coach_session.dart` | `CoachSession` (ذاكرة الأداء: ACPL، أخطاء الافتتاح/النهاية…) |
| `coach_home_screen.dart` | AI Chess Coach + حالة النموذج + الإعدادات |

## الاختيار (مقارنة موجزة)

**المشغّل:** `llama_flutter_android` (llama.cpp، MIT، أندرويد فقط، GGUF،
Vulkan اختياري، دعم 16KB pages، API 26+، NDK r27+). البديل: `flutter_gemma`
(LiteRT-LM/MediaPipe، متعدد المنصات). اخترنا llama.cpp لأن GGUF يفتح
كل النماذج الصغيرة المفتوحة ويسهّل استبدال النموذج.

**النموذج:** Qwen2.5-1.5B-Instruct Q4_K_M — Apache-2.0، ≈1.1 GB،
يدعم العربية والإنجليزية، قالب ChatML، بدون وضع تفكير. بدائل مدروسة:
Qwen3-1.7B (Apache-2.0، أحدث لكن وضع التفكير يعقّد الإخراج)،
Gemma 3 1B (≈0.7 GB، رخصة Gemma)، Llama 3.2 1B (رخصة Llama)،
SmolLM2 (عربية أضعف). لتبديل النموذج عدّل `kDefaultCoachModel` أو مرّر
تنفيذًا آخر إلى `LocalCoachService.useModel`.

## حدود معروفة

- جودة العربية عند 1.5B متوسطة؛ لذلك: JSON منظّم + رفض أي ناتج يذكر نقلة
  غير موجودة في بيانات المحرك + قوالب كـ Fallback دائم.
- يحتاج جهاز ARM64 بذاكرة ≥ 4 GB (يُفضَّل 6 GB). على الأجهزة الأضعف
  يعمل المدرب بالقوالب.
- النموذج لا يقرر: Best Move / legality / evaluation / mate / winner /
  classification — كلها من المحرك.
