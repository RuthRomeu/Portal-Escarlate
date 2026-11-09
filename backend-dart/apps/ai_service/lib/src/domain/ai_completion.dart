/// Resultado de uma conclusão de chat bem-sucedida.
class AiCompletion {
  const AiCompletion({
    required this.content,
    required this.provider,
    required this.model,
  });

  final String content;
  final String provider;
  final String model;

  Map<String, String> toJson() => {
        'content': content,
        'provider': provider,
        'model': model,
      };
}
