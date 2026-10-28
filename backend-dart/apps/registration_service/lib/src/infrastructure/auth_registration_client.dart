import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/registration.dart';

class HttpAuthRegistrationClient implements AuthRegistrationClient {
  const HttpAuthRegistrationClient(this.client, this.baseUrl, this.internalToken);

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
    final response = await client
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw const RegistrationException(
          503, 'Não foi possível consultar o usuário.');
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data['exists'] is! bool) {
      throw const FormatException('Resposta inválida do Auth.');
    }
    return data['exists'] as bool;
  }

  @override
  Future<void> createUser(PendingRegistration pending) async {
    final response = await client
        .post(baseUrl.resolve('/internal/auth/users'),
            headers: _headers,
            body: jsonEncode({
              'email': pending.email,
              'passwordHash': pending.passwordHash,
            }))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201 || response.statusCode == 200) return;

    // If Auth committed but Registration did not, a retry sees 409.
    // Confirm existence before treating that retry as completed.
    if (response.statusCode == 409 && await userExists(pending.email)) {
      return;
    }
    throw RegistrationException(
      response.statusCode >= 500 ? 503 : response.statusCode,
      'Não foi possível concluir o cadastro agora.',
    );
  }
}
