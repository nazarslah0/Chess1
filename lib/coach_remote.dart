import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_settings.dart';
import 'coach_llm.dart';

/// OpenAI-compatible API providers used by the chess coach.
class CoachApiPreset {
  final String id;
  final String label;
  final String baseUrl;
  final String defaultModel;
  final bool requiresKey;
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

const List<CoachApiPreset> kCoachApiPresets = <CoachApiPreset>[
  CoachApiPreset(
    id: 'groq',
    label: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    defaultModel: 'openai/gpt-oss-120b',
    requiresKey: true,
    keyUrl: 'https://console.groq.com/keys',
  ),
  CoachApiPreset(
    id: 'openrouter',
    label: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    defaultModel: 'openrouter/free',
    requiresKey: true,
    keyUrl: 'https://openrouter.ai/keys',
  ),
  CoachApiPreset(
    id: 'pollinations',
    label: 'Pollinations (بدون مفتاح)',
    baseUrl: 'https://gen.pollinations.ai/v1',
    defaultModel: 'openai',
    requiresKey: false,
    keyUrl: 'https://pollinations.ai',
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

/// أقل ميزانية رموز لنماذج التفكير (gpt-oss): جزء منها يذهب للتفكير
/// الداخلي قبل كتابة الجواب، فإذا كانت صغيرة يعود المحتوى فارغًا مع
/// finish_reason=length.
const int kReasoningMinTokens = 1500;

/// Remote coach: Stockfish remains responsible for chess calculation;
/// this class only sends the trusted engine facts to an LLM for explanation.
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
      if (key.isNotEmpty) {
        req.headers.set('Authorization', 'Bearer $key');
      }

      final isGroq = _preset.id == 'groq' || _baseUrl.contains('api.groq.com');
      final isGptOss = isGroq && _model.startsWith('openai/gpt-oss-');

      // نماذج التفكير تحتاج ميزانية أكبر من النص المطلوب نفسه.
      final budget = isGptOss && maxTokens < kReasoningMinTokens
          ? kReasoningMinTokens
          : maxTokens;

      final body = <String, dynamic>{
        'model': _model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        'temperature': temperature,
        if (isGptOss) 'max_completion_tokens': budget else 'max_tokens': budget,
        'stream': false,
        // low: تفكير أقصر = جواب أسرع وأرخص، ويكفي لشرح بيانات جاهزة.
        if (isGptOss) 'reasoning_effort': 'low',
        if (isGptOss) 'include_reasoning': false,
      };

      req.add(utf8.encode(jsonEncode(body)));

      final res = await req.close().timeout(timeout);
      final responseBody =
          await res.transform(utf8.decoder).join().timeout(timeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw _apiException(res.statusCode, responseBody, uri);
      }

      if (responseBody.trim().isEmpty) {
        throw const FormatException('API returned an empty HTTP response.');
      }

      dynamic json;
      try {
        json = jsonDecode(responseBody);
      } catch (_) {
        throw FormatException(
            'API returned invalid JSON: ${_safe(responseBody)}');
      }

      if (json is! Map) {
        throw FormatException(
            'API returned an invalid JSON object: ${_safe(responseBody)}');
      }

      final choices = json['choices'];
      if (choices is! List || choices.isEmpty) {
        final err = _errorMessage(json);
        throw FormatException(err == null
            ? 'API returned no choices: ${_safe(responseBody)}'
            : 'API error: $err');
      }

      final first = choices.first;
      if (first is! Map) {
        throw const FormatException('API returned an invalid choice object.');
      }

      final message = first['message'];
      if (message is! Map) {
        throw FormatException(
            'API response has no assistant message: ${_safe(responseBody)}');
      }

      final text = _contentText(message['content']).trim();
      if (text.isEmpty) {
        final finish = first['finish_reason'];

        // length = نفدت الرموز (غالبًا في التفكير الداخلي).
        if (finish == 'length') {
          throw const FormatException(
            'The model ran out of tokens before answering (reasoning '
            'model). Try a non-reasoning model such as '
            'llama-3.3-70b-versatile, or retry.',
          );
        }

        throw FormatException(
          'API returned empty content'
          '${finish == null ? '' : ' (finish_reason=$finish)'}: '
          '${_safe(responseBody)}',
        );
      }

      return text;
    } on TimeoutException {
      throw TimeoutException(
          'Coach API request timed out after ${timeout.inSeconds} seconds.');
    } on SocketException catch (e) {
      throw SocketException('Could not connect to coach API: ${e.message}');
    } finally {
      client.close(force: true);
      if (identical(_client, client)) _client = null;
    }
  }

  static String _contentText(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      final b = StringBuffer();
      for (final part in content) {
        if (part is String) b.write(part);
        if (part is Map && part['text'] is String) b.write(part['text']);
      }
      return b.toString();
    }
    return content?.toString() ?? '';
  }

  static String? _errorMessage(Map<dynamic, dynamic> json) {
    final error = json['error'];
    if (error is Map && error['message'] != null) {
      return error['message'].toString();
    }
    if (error is String) return error;
    if (json['message'] != null) return json['message'].toString();
    return null;
  }

  static HttpException _apiException(int code, String body, Uri uri) {
    String message;
    try {
      final decoded = jsonDecode(body);
      message = decoded is Map
          ? (_errorMessage(decoded) ?? _safe(body))
          : _safe(body);
    } catch (_) {
      message = _safe(body);
    }
    return HttpException('HTTP $code: $message', uri: uri);
  }

  static String _safe(String value, {int maxLength = 600}) {
    final redacted = value
        .replaceAll(RegExp(r'gsk_[A-Za-z0-9_-]+'), 'gsk_***REDACTED***')
        .replaceAll(
          RegExp(r'Bearer\s+[A-Za-z0-9._-]+', caseSensitive: false),
          'Bearer ***REDACTED***',
        );
    return redacted.length <= maxLength
        ? redacted
        : '${redacted.substring(0, maxLength)}...';
  }
}
