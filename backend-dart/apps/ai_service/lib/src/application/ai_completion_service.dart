import 'dart:async';

import '../domain/ai_completion.dart';
import '../domain/ai_config.dart';
import '../domain/chat_message.dart';
import '../infrastructure/openrouter_client.dart';

/// Orquestra o fallback de chaves e modelos com cooldown e cache em memória,
/// replicando fielmente a lógica de [completeWithFallback] do Node.js.
class AiCompletionService {
  AiCompletionService({
    required AiConfigRepository configRepository,
    required OpenRouterClient openRouter,
    Duration cooldown = const Duration(minutes: 5),
    Duration totalTimeout = const Duration(seconds: 40),
  })  : _repo = configRepository,
        _openRouter = openRouter,
        _cooldown = cooldown,
        _totalTimeout = totalTimeout;

  final AiConfigRepository _repo;
  final OpenRouterClient _openRouter;
  final Duration _cooldown;
  final Duration _totalTimeout;

  // Cache de configurações (equivalente a aiConfigsCache no Node).
  List<AiConfig>? _cache;
  Future<List<AiConfig>>? _cachePromise;

  // Mapa de targets em cooldown: "${apiKeyId}:${model}" → DateTime da falha.
  final Map<String, DateTime> _failedTargets = {};

  // ---------------------------------------------------------------------------
  // API pública
  // ---------------------------------------------------------------------------

  /// Executa a conclusão de chat com fallback automático de chaves e modelos.
  ///
  /// Lança [TimeoutException] se o prazo total for excedido.
  /// Lança [StateError] se não houver nenhuma chave/modelo disponível.
  Future<AiCompletion> complete({
    required List<ChatMessage> messages,
    double? temperature,
  }) async {
    var configs = await _getCachedConfigs();
    Object? lastError;
    var refreshedAfterFailure = false;
    final deadline = DateTime.now().add(_totalTimeout);

    while (true) {
      var refreshedDuringLoop = false;

      for (final config in configs) {
        if (config.provider != 'openrouter') continue;

        for (final model in config.models) {
          final remaining = deadline.difference(DateTime.now()).inMilliseconds;

          if (remaining <= 1000) {
            throw TimeoutException(
                'Tempo limite da requisicao de IA excedido.', _totalTimeout);
          }

          final targetId = '${config.apiKeyId}:$model';

          if (_isCoolingDown(targetId)) continue;

          try {
            final content = await _openRouter.complete(
              apiKey: config.apiKey,
              model: model,
              messages: messages.map((m) => m.toJson()).toList(),
              temperature: temperature,
              timeoutMs: remaining,
            );

            _failedTargets.remove(targetId);

            return AiCompletion(
              content: content,
              provider: config.provider,
              model: model,
            );
          } catch (e) {
            lastError = e;
            _failedTargets[targetId] = DateTime.now();

            print(
              '[ai-service] Falha no alvo de IA, tentando próximo fallback: '
              'provider=${config.provider} label=${config.label} model=$model '
              'error=${e.runtimeType}',
            );

            // Na primeira falha, força refresh do cache uma única vez.
            if (!refreshedAfterFailure) {
              configs = await _getCachedConfigs(forceRefresh: true);
              refreshedAfterFailure = true;
              refreshedDuringLoop = true;
              break; // Recomeça o loop externo com configs frescas.
            }
          }
        }

        if (refreshedDuringLoop) break;
      }

      if (!refreshedDuringLoop) break;
    }

    if (lastError != null) throw lastError;
    throw StateError('Nenhuma chave/modelo ativo configurado para IA.');
  }

  // ---------------------------------------------------------------------------
  // helpers internos
  // ---------------------------------------------------------------------------

  Future<List<AiConfig>> _getCachedConfigs(
      {bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;

    // Evita thundering herd: reutiliza a promise em voo.
    _cachePromise ??= _repo.listActive().then((configs) {
      _cache = configs;
      return configs;
    }).whenComplete(() {
      _cachePromise = null;
    });

    if (forceRefresh) {
      _cache = null;
      _cachePromise = _repo.listActive().then((configs) {
        _cache = configs;
        return configs;
      }).whenComplete(() {
        _cachePromise = null;
      });
    }

    return _cachePromise!;
  }

  bool _isCoolingDown(String targetId) {
    final failedAt = _failedTargets[targetId];
    if (failedAt == null) return false;
    if (DateTime.now().difference(failedAt) > _cooldown) {
      _failedTargets.remove(targetId);
      return false;
    }
    return true;
  }

  /// Força invalidação do cache (útil em testes).
  void invalidateCache() {
    _cache = null;
    _cachePromise = null;
  }
}
