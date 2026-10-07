import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_settings.dart';
import 'coach_llm.dart';

/// مزوّد API مجاني متوافق مع OpenAI (`/chat/completions`).
class CoachApiPreset {
  final String id;
  final String label;
  final String baseUrl;
  final String defaultModel;
  final bool requiresKey;

  /// صفحة الحصول على المفتاح المجاني.
  final String keyUrl;

  const CoachApiPreset({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.defaultModel,
    required this.requiresKey,
    required this.keyUrl,
  });
}

/// القيم الافتراضية قابلة للتعديل من الواجهة (الأسماء والحصص المجانية
/// تتغير عند المزوّدين، فلا نثبّتها في الكود).
const List<CoachApiPreset> kCoachApiPresets = <CoachApiPreset>[
  CoachApiPreset(
    id: 'groq',
    label: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    defaultModel: 'llama-3.3-70b-versatile',
    requiresKey: true,
    keyUrl: 'console.groq.com/keys',
  ),
  CoachApiPreset(
    id: 'openrouter',
    label: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    defaultModel: 'openrouter/free',
    requiresKey: true,
    keyUrl: 'openrouter.ai/keys',
  ),
  CoachApiPreset(
    id: 'pollinations',
    label: 'Pollinations (بدون مفتاح)',
    baseUrl: 'https://gen.pollinations.ai/v1',
    defaultModel: 'openai',
    requiresKey: false,
    keyUrl: 'pollinations.ai',
  ),
  CoachApiPreset(
    id: 'custom',
    label: 'مخصّص',
    baseUrl: '',
    defaultModel: '',
    requiresKey: false,
    keyUrl: '',
  ),
];

CoachApiPreset coachApiPreset(String id) => kCoachApiPresets.firstWhere(
      (p) => p.id == id,
      orElse: () => kCoachApiPresets.first,
    );

/// LocalCoachModel يعمل عبر API مجاني بدل ملف محلي (لا يستهلك
/// تخزينًا ولا ذاكرة). يُرسَل للمزوّد بيانات Stockfish المنظمة للنقلة
/// فقط (النقلة، التقييم، أفضل نقلة، الخط الرئيسي، المرحلة)؛ وفي «تحليل
/// وضعية» يُرسل أيضًا FEN. أي فشل يعيد المدرب إلى القوالب.
class RemoteCoachModel implements LocalCoachModel {
  RemoteCoachModel(this.settings);

  final AppSettings settings;

  HttpClient? _client;

  CoachApiPreset get _preset => coachApiPreset(settings.coachApiProvider);

  String get _baseUrl {
    final custom = settings.coachApiBaseUrl.trim();
    final b = custom.isNotEmpty ? custom : _preset.baseUrl;

    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }

  String get _model {
    final m = settings.coachApiModel.trim();

    return m.isNotEmpty ? m : _preset.defaultModel;
  }

  bool get _configured {
    if (_baseUrl.isEmpty || _model.isEmpty) return false;

    return !_preset.requiresKey || settings.coachApiKey.trim().isNotEmpty;
  }

  @override
  CoachModelSpec get spec => CoachModelSpec(
        id: 'remote-${_preset.id}',
        displayName: '${_preset.label} · $_model',
        url: _baseUrl,
        fileName: '',
        approxBytes: 0,
        license: 'Cloud API',
      );

  /// «محمَّل» = مُعدّ وجاهز للاستدعاء (لا شيء يُحمَّل في الذاكرة).
  @override
  bool get isLoaded => _configured;

  @override
  Future<bool> isInstalled() async => _configured;

  @override
  Future<void> load() async {
    if (!_configured) throw StateError('API is not configured');
  }

  @override
  Future<void> install(
    void Function(CoachDownloadProgress p) onProgress,
  ) async {
    throw UnsupportedError('Remote model needs no download');
  }

  @override
  void cancelInstall() {}

  /// «حذف» النموذج البعيد = مسح المفتاح المحفوظ.
  @override
  Future<void> uninstall() => settings.setCoachApiKey('');

  @override
  Future<void> unload() async {}

  @override
  Future<void> cancel() async {
    _client?.close(force: true);
    _client = null;
  }

  @override
  Future<String> generate({
    required String system,
    required String user,
    int maxTokens = 420,
    double temperature = 0.3,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (!_configured) throw StateError('API is not configured');

    final uri = Uri.parse('$_baseUrl/chat/completions');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);

    _client = client;

    try {
      final req = await client.postUrl(uri).timeout(timeout);

      req.headers.contentType = ContentType.json;
      req.headers.set('Accept', 'application/json');

      final key = settings.coachApiKey.trim();

      if (key.isNotEmpty) req.headers.set('Authorization', 'Bearer $key');

      req.add(
        utf8.encode(
          jsonEncode({
            'model': _model,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': user},
            ],
            'temperature': temperature,
            'max_tokens': maxTokens,
            'stream': false,
          }),
        ),
      );

      final res = await req.close().timeout(timeout);
      final body = await res.transform(utf8.decoder).join().timeout(timeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final snippet = body.length > 160 ? body.substring(0, 160) : body;

        throw HttpException('HTTP ${res.statusCode}: $snippet', uri: uri);
      }

      final json = jsonDecode(body);

      Object? content;
      if (json is Map &&
          json['choices'] is List &&
          (json['choices'] as List).isNotEmpty) {
        final first = (json['choices'] as List).first;
        final message = first is Map ? first['message'] : null;
        content = message is Map ? message['content'] : null;
      }

      if (content == null) throw const FormatException('Empty API reply');

      return content.toString();
    } finally {
      client.close(force: true);

      if (identical(_client, client)) _client = null;
    }
  }
}
