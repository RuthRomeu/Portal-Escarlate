import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/recovery.dart';

class HttpRecoveryAuthClient implements RecoveryAuthClient {
  const HttpRecoveryAuthClient(
      this.client, this.baseUrl, this.internalToken);

  final http.Client client;
  final Uri baseUrl;
  final String internalToken;

  Map<String, String> get _headers => {
        'x-internal-token': internalToken,
        'content-type': 'application/json',
      };

  @override
  Future<bool> userExists(String email) async {
    final url = baseUrl.resolve('/internal/auth/users/exists').replace(
      queryParameters: {'email': email},
    );
    final response = await client.get(url, headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw const RecoveryException(
          503, 'Nao foi possivel consultar o usuario agora.');
    }
    final body = jsonDecode(response.body);
    if (body is! Map || body['exists'] is! bool) {
      throw const FormatException('Resposta de Auth invalida.');
    }
    return body['exists'] as bool;
  }

  @override
  Future<void> changePassword(
      PendingRecovery pending, String password) async {
    final response = await client.post(
      baseUrl.resolve('/internal/auth/users/password'),
      headers: _headers,
      body: jsonEncode({
        'email': pending.email,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) return;

    throw RecoveryException(
      response.statusCode >= 500 ? 503 : response.statusCode,
      'Nao foi possivel atualizar a senha agora.',
    );
  }
}
