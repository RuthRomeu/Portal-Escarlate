/// Representa uma chave de API ativa com seus modelos ordenados por prioridade.
class AiConfig {
  const AiConfig({
    required this.apiKeyId,
    required this.provider,
    required this.label,
    required this.apiKey,
    required this.models,
  });

  final String apiKeyId;
  final String provider;
  final String? label;

  /// Chave decifrada (nunca persistir nem logar).
  final String apiKey;

  /// Modelos ordenados por (priority ASC, created_at ASC).
  final List<String> models;
}

/// Contrato do repositório de configurações de IA.
abstract interface class AiConfigRepository {
  Future<List<AiConfig>> listActive();
}
