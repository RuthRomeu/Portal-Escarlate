import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erro retornado pelo provedor OpenRouter / modelo downstream.
class AiProviderException implements Exception {
  const AiProviderException(
    this.message, {
    this.status,
    this.code,
    this.provider,
    this.model,
    this.rawMessage,
  });

  final String message;
  final int? status;
  final String? code;
  final String? provider;
  final String? model;
  final String? rawMessage;

  @override
  String toString() => 'AiProviderException($message)';
}

/// Erro genérico de IA (sem resposta válida).
class AiNoResponseException implements Exception {
  const AiNoResponseException(this.message);
  final String message;

  @override
  String toString() => 'AiNoResponseException($message)';
}

/// Cliente HTTP para a API do OpenRouter.
class OpenRouterClient {
  OpenRouterClient({
    required this.httpClient,
    required this.appUrl,
    Uri? endpoint,
  }) : _endpoint =
           endpoint ??
           Uri.parse('https://openrouter.ai/api/v1/chat/completions');

  final http.Client httpClient;
  final String appUrl;
  final Uri _endpoint;

  static const _maxTimeoutMs = 35000;
  static const _minTimeoutMs = 1000;

  /// Faz uma requisição de completion ao OpenRouter.
  ///
  /// Lança [AiProviderException] se o servidor retornou erro.
  /// Lança [AiNoResponseException] se a resposta não continha texto.
  /// Lança [TimeoutException] se exceder [timeoutMs].
  Future<String> complete({
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    double? temperature,
    int? timeoutMs,
  }) async {
    final effectiveTimeout = timeoutMs == null
        ? _maxTimeoutMs
        : timeoutMs.clamp(_minTimeoutMs, _maxTimeoutMs);

    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': (temperature ?? 0.3).clamp(0.0, 1.0),
    });

    final request = http.Request('POST', _endpoint)
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..headers['Content-Type'] = 'application/json'
      ..headers['HTTP-Referer'] = appUrl
      ..headers['X-Title'] = 'Portal Escarlate'
      ..body = body;

    final http.StreamedResponse streamed;
    try {
      streamed = await httpClient
          .send(request)
          .timeout(Duration(milliseconds: effectiveTimeout));
    } on TimeoutException {
      rethrow;
    }

    final responseBody = await streamed.stream
        .transform(utf8.decoder)
        .join()
        .timeout(Duration(milliseconds: effectiveTimeout));

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(responseBody);
      data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      data = <String, dynamic>{};
    }

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final err = _extractProviderError(data, streamed.statusCode);
      throw AiProviderException(
        err.message,
        status: streamed.statusCode,
        code: err.code,
        provider: err.provider,
        model: model,
        rawMessage: err.rawMessage,
      );
    }

    final choices = data['choices'];
    final content = choices is List && choices.isNotEmpty
        ? choices.first?['message']?['content']
        : null;

    if (content is! String || content.trim().isEmpty) {
      throw const AiNoResponseException(
        'A IA nao retornou uma resposta valida.',
      );
    }

    return content.trim();
  }

  // ---------------------------------------------------------------------------
  // helpers internos
  // ---------------------------------------------------------------------------

  _ProviderError _extractProviderError(Map<String, dynamic> data, int status) {
    final error = data['error'];
    final metadata = error is Map ? error['metadata'] : null;

    final rawMessage =
        (error is Map &&
            error['message'] is String &&
            (error['message'] as String).trim().isNotEmpty)
        ? (error['message'] as String).trim()
        : 'OpenRouter respondeu com status $status.';

    final providerMessage =
        (metadata is Map &&
            metadata['raw'] is String &&
            (metadata['raw'] as String).trim().isNotEmpty)
        ? (metadata['raw'] as String).trim()
        : '';

    final code =
        (error is Map && (error['code'] is String || error['code'] is int))
        ? error['code'].toString()
        : '';

    final provider =
        (metadata is Map &&
            metadata['provider_name'] is String &&
            (metadata['provider_name'] as String).trim().isNotEmpty)
        ? (metadata['provider_name'] as String).trim()
        : '';

    final effectiveMessage = providerMessage.isNotEmpty
        ? providerMessage
        : rawMessage;
    return _ProviderError(effectiveMessage, code, provider, effectiveMessage);
  }
}

class _ProviderError {
  const _ProviderError(this.message, this.code, this.provider, this.rawMessage);
  final String message;
  final String code;
  final String provider;
  final String rawMessage;
}
