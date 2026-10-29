import 'dart:convert';

import 'package:portal_http/portal_http.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../application/recovery_application.dart';
import '../domain/recovery.dart';

class RecoveryApi {
  const RecoveryApi(this.application);
  final RecoveryApplication application;

  void registerRoutes(Router router) {
    router.post('/api/auth/password/forgot',
        (Request request) => _handle(() => _forgot(request)));
    router.post('/api/auth/password/reset',
        (Request request) => _handle(() => _reset(request)));
    router.get('/internal/password-recovery/email-requests/<requestId>',
        (Request request, String requestId) =>
            _handle(() => _emailRequest(requestId)));
  }

  Future<Response> _handle(Future<Response> Function() action) async {
    try {
      return await action();
    } on RecoveryException catch (error) {
      return jsonReply(error.status, {'message': error.message});
    } on FormatException {
      return jsonReply(400, {
        'message': 'Nao foi possivel ler os dados da requisicao.',
      });
    } catch (error) {
      // Never log e-mails, code query params or passwords.
      print('[password-recovery] request error: ' +
          error.runtimeType.toString());
      return jsonReply(503, {
        'message': 'Nao foi possivel processar a recuperacao agora.',
      });
    }
  }

  Future<Map<String, dynamic>> _readBody(Request request) async {
    final bytes = <int>[];
    await for (final chunk in request.read()) {
      bytes.addAll(chunk);
      if (bytes.length > 16 * 1024) {
        throw const RecoveryException(
            413, 'Dados da recuperacao muito grandes.');
      }
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    return decoded;
  }

  Future<Response> _forgot(Request request) async {
    final body = await _readBody(request);
    final errors = forgotErrors(body);
    if (errors.isNotEmpty) {
      return jsonReply(400, {
        'message': errors.values.first.first,
        'fieldErrors': errors,
      });
    }
    // The Gateway overwrites forwarded IP using the socket address.
    final ip = request.headers['x-forwarded-for'] ?? 'unknown';
    await application.forgot(body['email'] as String, ip);
    return jsonReply(200, {'message': RecoveryApplication.genericMessage});
  }

  Future<Response> _reset(Request request) async {
    final code = request.url.queryParameters['code']?.trim();
    if (code == null || code.isEmpty) {
      return jsonReply(400, {'message': 'Codigo de recuperacao ausente.'});
    }
    final body = await _readBody(request);
    final errors = resetErrors(body);
    if (errors.isNotEmpty) {
      return jsonReply(400, {
        'message': errors.values.first.first,
        'fieldErrors': errors,
      });
    }
    final updated = await application.reset(
        code, body['password'] as String);
    if (!updated) {
      return jsonReply(400, {'message': 'Codigo expirado ou invalido.'});
    }
    return jsonReply(200, {
      'message': 'Senha redefinida com sucesso. Agora faca login com a nova senha.',
    });
  }

  Future<Response> _emailRequest(String requestId) async {
    final data = await application.emailRequest(requestId);
    return data == null
        ? jsonReply(404, {'message': 'Solicitacao indisponivel.'})
        : jsonReply(200, data);
  }
}
