import 'dart:convert';
import 'package:http/http.dart' as http;

abstract interface class ExternalApiClient {
  Future<Map<String, dynamic>> getJson(Uri uri, {Map<String, String> headers = const {}});
  Future<Map<String, dynamic>> postJson(Uri uri, Map<String, dynamic> body,
      {Map<String, String> headers = const {}});
  void close();
}

class HttpExternalApiClient implements ExternalApiClient {
  HttpExternalApiClient({http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  @override
  Future<Map<String, dynamic>> getJson(Uri uri, {Map<String, String> headers = const {}}) async {
    final response = await _client.get(uri, headers: headers).timeout(timeout);
    return _readJson(response);
  }

  @override
  Future<Map<String, dynamic>> postJson(Uri uri, Map<String, dynamic> body,
      {Map<String, String> headers = const {}}) async {
    final response = await _client.post(uri,
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode(body),
    ).timeout(timeout);
    return _readJson(response);
  }

  Map<String, dynamic> _readJson(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('API externa retornou HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Resposta JSON não é um objeto.');
    }
    return decoded;
  }

  @override
  void close() => _client.close();
}
