import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';

/// Resultado de uma operação de autenticação.
///
/// [ok] = true  → operação bem-sucedida, [data] contém o body JSON.
/// [ok] = false → falha, [message] contém a mensagem de erro para exibir.
class AuthResult {
  const AuthResult.success(this.data) : ok = true, message = null;
  const AuthResult.failure(this.message) : ok = false, data = null;

  final bool ok;
  final Map<String, dynamic>? data;
  final String? message;
}

/// Representa o usuário autenticado, devolvido pelo endpoint /api/auth/me.
class AuthUser {
  const AuthUser({required this.id, required this.email, required this.role});

  final String id;
  final String email;
  final String role;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    role: json['role'] as String,
  );
}

/// Cliente HTTP para os endpoints de autenticação do gateway.
///
/// Segue o mesmo contrato JSON que o Node.js (backend/src/services/auth/).
/// Todos os cookies de sessão são gerenciados automaticamente pelo http.Client
/// no Flutter Web. Em mobile, o cookie `portal_session` é recebido no header
/// Set-Cookie e precisa ser reenviado manualmente — por isso usamos
/// [CookieJarClient] que extrai e persiste o cookie entre requisições.
class AuthApiClient {
  AuthApiClient({http.Client? client})
    : _jar = CookieJarClient(inner: client ?? http.Client());

  final CookieJarClient _jar;

  /// Expõe o jar para que outros clients (ex: NewsApiClient) possam
  /// reutilizar o cookie de sessão sem criar uma nova instância.
  CookieJarClient get jar => _jar;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  // ---------------------------------------------------------------------------
  // Login — POST /api/auth/login
  // ---------------------------------------------------------------------------

  /// Autentica o usuário com e-mail e senha.
  ///
  /// Em caso de sucesso, o cookie `portal_session` é armazenado
  /// automaticamente pelo [CookieJarClient] para requisições futuras.
  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await _jar.post(
        _uri('/api/auth/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );
      final body = _parseBody(response);
      if (response.statusCode == 200) return AuthResult.success(body);
      return AuthResult.failure(_extractMessage(body, response.statusCode));
    } on Exception {
      return const AuthResult.failure(
        'Não foi possível conectar ao servidor. Verifique sua conexão.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Cadastro — POST /api/auth/register
  // ---------------------------------------------------------------------------

  /// Inicia o fluxo de cadastro (envia e-mail de verificação).
  ///
  /// O backend (Registration Service) valida o e-mail, cria um token
  /// temporário e dispara o e-mail de confirmação. A conta só é criada
  /// após o usuário clicar no link recebido.
  Future<AuthResult> register(String email, String password) async {
    try {
      final response = await _jar.post(
        _uri('/api/auth/register'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );
      final body = _parseBody(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResult.success(body);
      }
      return AuthResult.failure(_extractMessage(body, response.statusCode));
    } on Exception {
      return const AuthResult.failure(
        'Não foi possível conectar ao servidor. Verifique sua conexão.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Recuperação de senha — POST /api/auth/password/forgot
  // ---------------------------------------------------------------------------

  /// Solicita um link de redefinição de senha por e-mail.
  ///
  /// O backend retorna 200 mesmo que o e-mail não exista (segurança:
  /// não revela quais e-mails estão cadastrados).
  Future<AuthResult> forgotPassword(String email) async {
    try {
      final response = await _jar.post(
        _uri('/api/auth/password/forgot'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      );
      final body = _parseBody(response);
      if (response.statusCode == 200) return AuthResult.success(body);
      return AuthResult.failure(_extractMessage(body, response.statusCode));
    } on Exception {
      return const AuthResult.failure(
        'Não foi possível conectar ao servidor. Verifique sua conexão.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Redefinição de senha — POST /api/auth/password/reset
  // ---------------------------------------------------------------------------

  /// Redefine a senha usando o token recebido por e-mail.
  Future<AuthResult> resetPassword(String token, String password) async {
    try {
      final response = await _jar.post(
        _uri('/api/auth/password/reset'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'token': token, 'password': password}),
      );
      final body = _parseBody(response);
      if (response.statusCode == 200) return AuthResult.success(body);
      return AuthResult.failure(_extractMessage(body, response.statusCode));
    } on Exception {
      return const AuthResult.failure(
        'Não foi possível conectar ao servidor. Verifique sua conexão.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Logout — POST /api/auth/logout
  // ---------------------------------------------------------------------------

  /// Encerra a sessão e limpa o cookie local.
  Future<void> logout() async {
    try {
      await _jar.post(
        _uri('/api/auth/logout'),
        headers: {'content-type': 'application/json'},
        body: '{}',
      );
    } on Exception {
      // Mesmo com falha de rede, limpa o cookie local.
    } finally {
      _jar.clearCookies();
    }
  }

  // ---------------------------------------------------------------------------
  // Sessão atual — GET /api/auth/me
  // ---------------------------------------------------------------------------

  /// Valida a sessão atual e retorna os dados do usuário autenticado.
  Future<AuthUser?> me() async {
    try {
      final response = await _jar.get(_uri('/api/auth/me'));
      if (response.statusCode != 200) return null;
      final body = _parseBody(response);
      final user = body['user'];
      if (user is! Map<String, dynamic>) return null;
      return AuthUser.fromJson(user);
    } on Exception {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _parseBody(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on Exception {
      // body inválido — retorna vazio
    }
    return {};
  }

  String _extractMessage(Map<String, dynamic> body, int status) {
    final msg = body['message'];
    if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    return switch (status) {
      401 => 'E-mail ou senha incorretos.',
      409 => 'Já existe uma conta com este e-mail.',
      429 => 'Muitas tentativas. Tente novamente em alguns minutos.',
      400 => 'Dados inválidos. Verifique o formulário.',
      _ => 'Erro inesperado (HTTP $status).',
    };
  }
}

// ---------------------------------------------------------------------------
// CookieJarClient — persiste o cookie de sessão entre requisições
// ---------------------------------------------------------------------------

/// Wrapper de [http.Client] que extrai o cookie `portal_session` da resposta
/// e o reenvia automaticamente nas próximas requisições.
///
/// Por que é necessário?
/// No Flutter mobile (Android/iOS), o pacote `http` não tem um jar de cookies
/// embutido (diferente do browser). O backend envia `Set-Cookie: portal_session=...`
/// e espera que o cliente reenvie `Cookie: portal_session=...` nas chamadas
/// subsequentes. Esta classe faz isso manualmente.
class CookieJarClient {
  CookieJarClient({required this.inner});

  final http.Client inner;
  String? _sessionCookie; // Valor do cookie portal_session

  void clearCookies() => _sessionCookie = null;

  Map<String, String> _withCookie(Map<String, String>? headers) {
    final result = Map<String, String>.from(headers ?? {});
    if (_sessionCookie != null) {
      result['cookie'] = 'portal_session=$_sessionCookie';
    }
    return result;
  }

  void _saveCookie(http.Response response) {
    // O header Set-Cookie pode conter múltiplos valores. Procuramos pelo
    // cookie `portal_session`.
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null) return;
    // Formato: "portal_session=TOKEN; Path=/; HttpOnly; ..."
    final match = RegExp(r'portal_session=([^;]+)').firstMatch(setCookie);
    if (match != null) {
      _sessionCookie = match.group(1);
    }
  }

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final response = await inner.get(url, headers: _withCookie(headers));
    _saveCookie(response);
    return response;
  }

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await inner.post(
      url,
      headers: _withCookie(headers),
      body: body,
    );
    _saveCookie(response);
    return response;
  }
}
