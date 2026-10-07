import 'dart:async';
import 'dart:io';

import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path_provider/path_provider.dart';

// ================================================================
// النموذج اللغوي المحلي.
//
// LocalCoachModel = الواجهة التي يعتمد عليها باقي التطبيق. لاستبدال
// النموذج لاحقًا (SmallModel ← BetterModel) يكفي تغيير
// [CoachModelSpec] أو كتابة تنفيذ آخر للواجهة، بدون تعديل أي شاشة.
//
// التنفيذ الحالي: llama.cpp عبر llama_flutter_android (MIT) على
// أندرويد، بنموذج GGUF مُكمَّم 4-bit يُحمَّل مرة واحدة ثم يعمل بدون
// إنترنت.
// ================================================================

/// مواصفات نموذج المدرب (قابلة للاستبدال).
class CoachModelSpec {
  final String id;
  final String displayName;
  final String url;
  final String fileName;
  final int approxBytes;
  final String license;

  /// قالب المحادثة في llama_flutter_android.
  final String chatTemplate;

  const CoachModelSpec({
    required this.id,
    required this.displayName,
    required this.url,
    required this.fileName,
    required this.approxBytes,
    required this.license,
    this.chatTemplate = 'chatml',
  });
}

/// النموذج الافتراضي: Qwen2.5-1.5B-Instruct (Q4_K_M).
/// - ترخيص Apache-2.0، ويدعم العربية والإنجليزية ضمن لغاته.
/// - حجم ≈ 1.1 GB، ويعمل على ARM64 بذاكرة ≈ 1.5–2 GB أثناء الاستخدام.
/// - يستخدم قالب ChatML وبدون وضع تفكير (لا `<think>`).
const CoachModelSpec kDefaultCoachModel = CoachModelSpec(
  id: 'qwen2.5-1.5b-instruct-q4_k_m',
  displayName: 'Qwen2.5 1.5B Instruct (Q4_K_M)',
  url: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/'
      'qwen2.5-1.5b-instruct-q4_k_m.gguf',
  fileName: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
  approxBytes: 1120000000,
  license: 'Apache-2.0',
);

/// واجهة النموذج المحلي.
abstract class LocalCoachModel {
  CoachModelSpec get spec;

  bool get isLoaded;

  /// هل ملف النموذج موجود على الجهاز؟
  Future<bool> isInstalled();

  /// ينزّل النموذج مرة واحدة (يحتاج إنترنت هذه المرة فقط).
  Future<void> install(void Function(CoachDownloadProgress p) onProgress);

  void cancelInstall();

  /// يحذف ملف النموذج من الجهاز.
  Future<void> uninstall();

  /// يحمّل النموذج في الذاكرة (يرمي استثناء عند الفشل).
  Future<void> load();

  /// يولّد نصًا. يرمي TimeoutException إذا تجاوز [timeout].
  Future<String> generate({
    required String system,
    required String user,
    int maxTokens = 420,
    double temperature = 0.3,
    Duration timeout = const Duration(seconds: 45),
  });

  /// يوقف التوليد الجاري.
  Future<void> cancel();

  /// يحرّر الذاكرة.
  Future<void> unload();
}

/// تقدّم التنزيل.
class CoachDownloadProgress {
  final int received;
  final int total;

  const CoachDownloadProgress(this.received, this.total);

  double get fraction => total <= 0 ? 0 : (received / total).clamp(0.0, 1.0);
}

/// تخزين ملفات النموذج وتنزيلها (مرة واحدة؛ بعدها Offline).
class CoachModelStore {
  CoachModelStore(this.spec);

  final CoachModelSpec spec;

  bool _cancelDownload = false;

  Future<File> file() async {
    final dir = await getApplicationSupportDirectory();
    final d = Directory('${dir.path}/coach_models');

    if (!await d.exists()) await d.create(recursive: true);

    return File('${d.path}/${spec.fileName}');
  }

  Future<bool> exists() async {
    final f = await file();

    if (!await f.exists()) return false;

    // ملف ناقص (تنزيل متقطع) لا يُعدّ مثبّتًا.
    return await f.length() > spec.approxBytes * 0.9;
  }

  void cancelDownload() => _cancelDownload = true;

  /// ينزّل النموذج إلى ملف مؤقت ثم يعيد تسميته. يرمي عند الفشل.
  Future<void> download(
    void Function(CoachDownloadProgress p) onProgress,
  ) async {
    _cancelDownload = false;

    final target = await file();
    final part = File('${target.path}.part');

    if (await part.exists()) await part.delete();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);

    IOSink? sink;

    try {
      final req = await client.getUrl(Uri.parse(spec.url));
      final res = await req.close();

      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(spec.url));
      }

      final total =
          res.contentLength > 0 ? res.contentLength : spec.approxBytes;

      sink = part.openWrite();

      var received = 0;
      var lastReport = 0;

      await for (final chunk in res) {
        if (_cancelDownload) throw const _DownloadCancelled();

        sink.add(chunk);

        received += chunk.length;

        // لا نغمر الواجهة: تحديث كل ~512 KB.
        if (received - lastReport > 512 * 1024) {
          lastReport = received;

          onProgress(CoachDownloadProgress(received, total));
        }
      }

      await sink.flush();
      await sink.close();

      sink = null;

      if (received < spec.approxBytes * 0.9) {
        throw const HttpException('Incomplete download');
      }

      if (await target.exists()) await target.delete();

      await part.rename(target.path);

      onProgress(CoachDownloadProgress(received, total));
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}

      if (await part.exists()) await part.delete();

      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> delete() async {
    final f = await file();

    if (await f.exists()) await f.delete();
  }
}

class _DownloadCancelled implements Exception {
  const _DownloadCancelled();

  @override
  String toString() => 'download cancelled';
}

/// تنفيذ LocalCoachModel بـ llama.cpp (llama_flutter_android).
class LlamaCppCoachModel implements LocalCoachModel {
  LlamaCppCoachModel({
    this.spec = kDefaultCoachModel,
    this.threads = 4,
    this.contextSize = 2048,
  }) : store = CoachModelStore(spec);

  @override
  final CoachModelSpec spec;

  final CoachModelStore store;
  final int threads;
  final int contextSize;

  LlamaController? _controller;

  @override
  bool get isLoaded => _controller != null;

  @override
  Future<bool> isInstalled() => store.exists();

  @override
  Future<void> install(
    void Function(CoachDownloadProgress p) onProgress,
  ) =>
      store.download(onProgress);

  @override
  void cancelInstall() => store.cancelDownload();

  @override
  Future<void> uninstall() async {
    await unload();
    await store.delete();
  }

  @override
  Future<void> load() async {
    if (_controller != null) return;

    final f = await store.file();

    if (!await store.exists()) {
      throw StateError('Coach model is not installed');
    }

    final c = LlamaController();

    try {
      // CPU فقط (gpuLayers الافتراضي) للاستقرار على كل الأجهزة، ولا
      // نتنافس مع Stockfish على موارد أخرى.
      await c.loadModel(
        modelPath: f.path,
        threads: threads,
        contextSize: contextSize,
      );
    } catch (_) {
      try {
        await c.dispose();
      } catch (_) {}

      rethrow;
    }

    _controller = c;
  }

  @override
  Future<String> generate({
    required String system,
    required String user,
    int maxTokens = 420,
    double temperature = 0.3,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final c = _controller;

    if (c == null) throw StateError('Coach model is not loaded');

    final buf = StringBuffer();
    final done = Completer<String>();

    final sub = c
        .generateChat(
          messages: [
            ChatMessage(role: 'system', content: system),
            ChatMessage(role: 'user', content: user),
          ],
          template: spec.chatTemplate,
          temperature: temperature,
          maxTokens: maxTokens,
        )
        .listen(
          buf.write,
          onDone: () {
            if (!done.isCompleted) done.complete(buf.toString());
          },
          onError: (Object e, StackTrace s) {
            if (!done.isCompleted) done.completeError(e, s);
          },
          cancelOnError: true,
        );

    try {
      return await done.future.timeout(timeout);
    } on TimeoutException {
      try {
        await c.stop();
      } catch (_) {}

      rethrow;
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> cancel() async {
    final c = _controller;

    if (c == null) return;

    try {
      await c.stop();
    } catch (_) {}
  }

  @override
  Future<void> unload() async {
    final c = _controller;

    _controller = null;

    if (c == null) return;

    try {
      await c.dispose();
    } catch (_) {}
  }
}
