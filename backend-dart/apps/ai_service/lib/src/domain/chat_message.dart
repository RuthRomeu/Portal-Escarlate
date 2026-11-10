/// Papéis aceitos pela API do OpenRouter / OpenAI.
enum ChatRole { system, user, assistant }

extension ChatRoleX on ChatRole {
  String get value => name; // 'system', 'user', 'assistant'
}

/// Mensagem normalizada para o modelo de IA.
class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final ChatRole role;
  final String content;

  Map<String, String> toJson() => {'role': role.value, 'content': content};

  /// Normaliza uma entrada bruta descartando conteúdo vazio.
  /// Papéis inválidos são mapeados para [ChatRole.user], como no Node.js.
  static ChatMessage? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final content = raw['content'];
    if (content is! String || content.trim().isEmpty) return null;
    final roleStr = raw['role'];
    final role = ChatRole.values.firstWhere(
      (r) => r.value == roleStr,
      orElse: () => ChatRole.user,
    );
    return ChatMessage(role: role, content: content.trim());
  }
}
