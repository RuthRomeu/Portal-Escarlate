import 'dart:async';
import 'dart:convert';

import 'package:portal_events/portal_events.dart';
import 'package:portal_http/portal_http.dart';
import 'package:portal_http/session_verifier.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../application/ai_completion_service.dart';
import '../domain/chat_message.dart';

/// Camada de apresentação HTTP do serviço de IA.
///
/// Rotas:
///   POST /api/ai/chat          — pública (exige cookie de sessão)
///   POST /internal/ai/chat     — interna (protegida por x-internal-token via middleware)
///
/// Contrato JSON 100% compatível com o Node.js.
class AiApi {
  const AiApi({
    required this.completionService,
    required this.sessions,
    required this.eventBus,
    required this.appUrl,
  });

  final AiCompletionService completionService;
  final SessionVerifier sessions;
  final EventBus? eventBus;
  final String appUrl;

  static const _aiUnavailableMessage = 'IA invalida no momento.';
  static const _maxBodyBytes = 1024 * 1024; // 1 MB

  void registerRoutes(Router router) {
    router.post(
      '/api/ai/chat',
      (Request r) => _handle(() => _chatCompletion(r, requireSession: true)),
    );
    router.post(
      '/internal/ai/chat',
      (Request r) => _handle(() => _chatCompletion(r, requireSession: false)),
    );
  }

  // ---------------------------------------------------------------------------
  // handlers
  // ---------------------------------------------------------------------------

  Future<Response> _chatCompletion(
    Request request, {
    required bool requireSession,
  }) async {
    // Verifica sessão na rota pública.
    if (requireSession && sessions.user(request) == null) {
      return jsonReply(401, {
        'message': 'Sessao invalida. Faca login novamente.',
      });
    }

    // Lê e desserializa o corpo.
    final Map<String, dynamic> payload;
    try {
      payload = await _readJson(request);
    } on _BodyTooLargeException {
      return jsonReply(413, {'message': 'Requisicao de IA muito grande.'});
    } on FormatException {
      return jsonReply(400, {
        'message': 'Nao foi possivel ler os dados da requisicao de IA.',
      });
    }

    // Normaliza mensagens.
    final rawMessages = payload['messages'];
    final messages =
        (rawMessages is List
                ? rawMessages.map(ChatMessage.tryParse).whereType<ChatMessage>()
                : const <ChatMessage>[])
            .toList();

    if (messages.isEmpty) {
      return jsonReply(400, {
        'message': 'Informe ao menos uma mensagem para a IA.',
      });
    }

    final temperatureRaw = payload['temperature'];
    final temperature = temperatureRaw is num
        ? temperatureRaw.toDouble().clamp(0.0, 1.0)
        : null;

    // Chama o serviço de completion com fallback.
    try {
      final result = await completionService.complete(
        messages: messages,
        temperature: temperature,
      );

      _publishSafely(
        EventEnvelope.create(
          type: 'portal.ai.chat_completed',
          source: 'ai-service',
          payload: {
            'provider': result.provider,
            'model': result.model,
            'route': requireSession ? 'public' : 'internal',
          },
        ),
      );

      return jsonReply(200, result.toJson());
    } catch (error) {
      print(
        '[ai-service] Falha ao completar requisição de IA: '
        '${error.runtimeType}',
      );

      _publishSafely(
        EventEnvelope.create(
          type: 'portal.ai.chat_failed',
          source: 'ai-service',
          payload: {'route': requireSession ? 'public' : 'internal'},
        ),
      );

      return jsonReply(500, {'message': _aiUnavailableMessage});
    }
  }

  // ---------------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------------

  Future<Response> _handle(Future<Response> Function() action) async {
    try {
      return await action();
    } catch (error) {
      print('[ai-service] Erro não tratado: ${error.runtimeType}');
      return jsonReply(500, {'message': 'Erro interno do servico de IA.'});
    }
  }

  Future<Map<String, dynamic>> _readJson(Request request) async {
    final bytes = <int>[];
    await for (final chunk in request.read()) {
      bytes.addAll(chunk);
      if (bytes.length > _maxBodyBytes) throw const _BodyTooLargeException();
    }
    if (bytes.isEmpty) return <String, dynamic>{};
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is Map<String, dynamic>) return value;
      return <String, dynamic>{};
    } on FormatException {
      rethrow;
    }
  }

  /// Publica um evento de forma não-bloqueante; erros são absorvidos.
  void _publishSafely(EventEnvelope event) {
    eventBus?.publish(event).catchError((Object e) {
      print('[ai-service] Falha ao publicar evento: ${e.runtimeType}');
    });
  }
}

class _BodyTooLargeException implements Exception {
  const _BodyTooLargeException();
}
