import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/data/auth_api_client.dart';

/// Status de saúde de uma conexão de e-mail.
class ConnectionHealth {
  const ConnectionHealth({required this.status, required this.message});

  /// valid, expired, inactive, unsupported
  final String status;
  final String message;

  factory ConnectionHealth.fromJson(Map<String, dynamic> json) =>
      ConnectionHealth(
        status: json['status'] as String? ?? 'unknown',
        message: json['message'] as String? ?? '',
      );
}

/// Conexão de e-mail cadastrada (Gmail OAuth).
class EmailConnection {
  const EmailConnection({
    required this.id,
    required this.provider,
    required this.email,
    required this.active,
    required this.priority,
    required this.health,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String provider;
  final String email;
  final bool active;
  final int priority;
  final ConnectionHealth health;
  final String? createdAt;
  final String? updatedAt;

  factory EmailConnection.fromJson(Map<String, dynamic> json) {
    final healthJson = json['health'] as Map<String, dynamic>? ?? {};
    return EmailConnection(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      email: json['email'] as String? ?? '',
      active: json['active'] as bool? ?? false,
      priority: json['priority'] as int? ?? 0,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      health: ConnectionHealth.fromJson(healthJson),
    );
  }
}

/// Resultado da lista de conexões de e-mail.
class EmailConnectionsResult {
  const EmailConnectionsResult.success({required this.connections})
    : ok = true,
      message = null;

  const EmailConnectionsResult.failure(this.message)
    : ok = false,
      connections = const [];

  final bool ok;
  final List<EmailConnection> connections;
  final String? message;
}

/// Resultado da solicitação de OAuth do Google.
class GoogleOAuthResult {
  const GoogleOAuthResult.success({required this.url})
    : ok = true,
      message = null;

  const GoogleOAuthResult.failure(this.message) : ok = false, url = null;

  final bool ok;
  final String? url;
  final String? message;
}

/// Cliente HTTP para as rotas administrativas de e-mail.
///
/// Rotas utilizadas (todas admin-only, via gateway porta 3000):
/// - GET /api/email-connections (lista conexões)
/// - POST /api/email-connections/google/start (inicia OAuth Google)
/// - DELETE /api/email-connections/:id (remove conexão)
class AdminApiClient {
  AdminApiClient({required CookieJarClient cookieJar}) : _jar = cookieJar;

  final CookieJarClient _jar;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Lista todas as conexões de e-mail cadastradas.
  Future<EmailConnectionsResult> getEmailConnections() async {
    try {
      final response = await _jar.get(_uri('/api/email-connections'));

      if (response.statusCode == 401) {
        return const EmailConnectionsResult.failure(
          'Sessão expirada. Faça login novamente.',
        );
      }

      if (response.statusCode == 403) {
        return const EmailConnectionsResult.failure(
          'Acesso restrito a administradores.',
        );
      }

      if (response.statusCode != 200) {
        return EmailConnectionsResult.failure(
          'Erro ao carregar conexões (HTTP ${response.statusCode}).',
        );
      }

      final body = _parseBody(response);
      final rawConnections = body['connections'];
      final connections = rawConnections is List
          ? rawConnections
                .whereType<Map<String, dynamic>>()
                .map(EmailConnection.fromJson)
                .toList()
          : <EmailConnection>[];

      return EmailConnectionsResult.success(connections: connections);
    } on Exception {
      return const EmailConnectionsResult.failure(
        'Não foi possível conectar ao servidor. Verifique sua conexão.',
      );
    }
  }

  /// Inicia o fluxo OAuth do Google e retorna a URL de autorização.
  Future<GoogleOAuthResult> startGoogleOAuth() async {
    try {
      final response = await _jar.post(
        _uri('/api/email-connections/google/start'),
        headers: {'content-type': 'application/json'},
        body: '{}',
      );

      if (response.statusCode != 200) {
        final body = _parseBody(response);
        final msg = body['message'];
        return GoogleOAuthResult.failure(
          msg is String && msg.isNotEmpty ? msg : 'Erro ao iniciar OAuth.',
        );
      }

      final body = _parseBody(response);
      final url = body['url'] as String?;

      if (url != null && url.isNotEmpty) {
        return GoogleOAuthResult.success(url: url);
      }

      return const GoogleOAuthResult.failure('URL de OAuth não retornada.');
    } on Exception {
      return const GoogleOAuthResult.failure(
        'Não foi possível conectar ao servidor.',
      );
    }
  }

  /// Remove uma conexão de e-mail pelo ID.
  Future<bool> deleteConnection(String id) async {
    try {
      final response = await _jar.delete(_uri('/api/email-connections/$id'));
      return response.statusCode == 204 || response.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  /// Atualiza a prioridade de uma conexão (PATCH /api/email-connections/:id/priority).
  Future<bool> updateConnectionPriority(String id, int priority) async {
    try {
      final response = await _jar.patch(
        _uri('/api/email-connections/$id/priority'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'priority': priority}),
      );
      return response.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  Map<String, dynamic> _parseBody(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on Exception {
      // body inválido
    }
    return {};
  }
}
