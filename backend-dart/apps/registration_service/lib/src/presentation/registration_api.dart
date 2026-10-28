import 'dart:convert';

import 'package:portal_http/portal_http.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../application/registration_application.dart';
import '../domain/registration.dart';

class RegistrationApi {
  const RegistrationApi(this.application);

  final RegistrationApplication application;

  void registerRoutes(Router router) {
    router.post('/api/auth/register/request',
        (Request request) => _handle(() => _request(request)));
    router.post('/api/auth/register',
        (Request request) => _handle(() => _request(request)));
    router.get('/api/auth/verify-email',
        (Request request) => _handle(() => _verify(request)));
    router.get('/internal/registration/email-requests/<requestId>',
        (Request request, String requestId) =>
            _handle(() => _emailRequest(requestId)));
  }

  Future<Response> _handle(Future<Response> Function() run) async {
    try {
      return await run();
    } on RegistrationException catch (error) {
      return jsonReply(error.status, {'message': error.message});
    } on FormatException {
      return jsonReply(400, {
        'message': 'Nao foi possivel ler os dados do cadastro.',
      });
    } catch (error) {
      // Log only the exception type, not submitted passwords or tokens.
      print('[registration] request failure: ' +
          error.runtimeType.toString());
      return jsonReply(503, {
        'message': 'Nao foi possivel processar o cadastro agora.',
      });
    }
  }

  Future<Map<String, dynamic>> _readJson(Request request) async {
    final data = <int>[];
    await for (final chunk in request.read()) {
      data.addAll(chunk);
      if (data.length > 16 * 1024) {
        throw const RegistrationException(
            413, 'Dados do cadastro muito grandes.');
      }
    }
    final decoded = jsonDecode(utf8.decode(data));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    return decoded;
  }

  Future<Response> _request(Request request) async {
    final body = await _readJson(request);
    final errors = registrationErrors(body);
    if (errors.isNotEmpty) {
      return jsonReply(400, {
        'message': errors.values.first.first,
        'fieldErrors': errors,
      });
    }
    // x-forwarded-for is set by the trusted Gateway from socket information.
    // It must not be copied from client-supplied headers by the Gateway.
    final ip = request.headers['x-forwarded-for'] ?? 'unknown';
    await application.request(body, ip);
    return jsonReply(200, {'message': RegistrationApplication.requestMessage});
  }

  Future<Response> _verify(Request request) async {
    final code = request.url.queryParameters['code']?.trim();
    if (code == null || code.isEmpty) {
      return jsonReply(400, {'message': 'Codigo de verificacao ausente.'});
    }
    if (!await application.verify(code)) {
      return jsonReply(400, {'message': 'Codigo expirado ou invalido.'});
    }
    return jsonReply(200, {
      'message': 'E-mail verificado com sucesso. Agora faca login para acessar.',
    });
  }

  Future<Response> _emailRequest(String requestId) async {
    final data = await application.emailRequest(requestId);
    return data == null
        ? jsonReply(404, {'message': 'Solicitacao indisponivel.'})
        : jsonReply(200, data);
  }
}
