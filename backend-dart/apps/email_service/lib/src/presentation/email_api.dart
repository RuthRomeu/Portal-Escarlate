import 'dart:convert';

import 'package:portal_http/portal_http.dart';
import 'package:portal_http/session_verifier.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../application/gmail_delivery.dart';
import '../domain/email_connection.dart';
import '../infrastructure/google_oauth.dart';

class EmailApi {
  const EmailApi(this.connections, this.oauth, this.delivery, this.sessions);

  final EmailConnectionRepository connections;
  final GoogleOAuth oauth;
  final EmailDelivery delivery;
  final SessionVerifier sessions;

  void registerRoutes(Router router) {
    router.get('/api/email-connections', (Request r) => _handle(() => _list(r)));
    router.post('/api/email-connections/google/start',
        (Request r) => _handle(() => _start(r)));
    router.get('/api/email-connections/google/callback',
        (Request r) => _handle(() => _callback(r)));
    router.get('/api/google/callback',
        (Request r) => _handle(() => _callback(r)));
    router.patch('/api/email-connections/<id>/priority',
        (Request r, String id) => _handle(() => _priority(r, id)));
    router.delete('/api/email-connections/<id>',
        (Request r, String id) => _handle(() => _delete(r, id)));
    router.post('/internal/email/verification',
        (Request r) => _handle(() => _sendLegacyVerification(r)));
  }

  Response? _checkAdmin(Request request) {
    final session = sessions.user(request);
    if (session == null) {
      return jsonReply(401, {'message': 'Sessao invalida.'});
    }
    if (session.role != 'admin') {
      return jsonReply(403, {'message': 'Acesso restrito a administradores.'});
    }
    return null;
  }

  Future<Response> _handle(Future<Response> Function() action) async {
    try {
      return await action();
    } on FormatException {
      return jsonReply(400, {'message': 'Dados invalidos.'});
    } catch (error) {
      // Never log OAuth codes, credentials or message bodies.
      print('[email] request failed: ' + error.runtimeType.toString());
      return jsonReply(502, {'message': 'Servico de e-mail indisponivel.'});
    }
  }

  Future<Response> _list(Request request) async {
    final denied = _checkAdmin(request);
    if (denied != null) return denied;
    final items = <Map<String, dynamic>>[];
    for (final connection in await connections.list()) {
      Map<String, String> health;
      if (!connection.active) {
        health = {'status': 'inactive', 'message': 'Conexao inativa.'};
      } else if (connection.provider != 'gmail') {
        health = {'status': 'unsupported', 'message': 'Provedor nao suportado.'};
      } else {
        try {
          await oauth.refresh(connection.refreshToken);
          health = {'status': 'valid', 'message': 'Refresh token valido.'};
        } catch (_) {
          health = {'status': 'expired', 'message': 'Conexao indisponivel.'};
        }
      }
      items.add(connection.publicJson(health: health));
    }
    return jsonReply(200, {'connections': items});
  }

  Future<Response> _start(Request request) async {
    final denied = _checkAdmin(request);
    if (denied != null) return denied;
    final session = sessions.user(request)!;
    return jsonReply(200, {
      'url': oauth.authorizationUrl(session.userId, session.email).toString(),
    });
  }

  Future<Response> _callback(Request request) async {
    final state = oauth.parseState(request.url.queryParameters['state']);
    final code = request.url.queryParameters['code'];
    if (state == null || code == null || code.trim().isEmpty) {
      return Response.found(oauth.adminRedirect('invalid').toString());
    }
    try {
      final result = await oauth.exchange(code);
      await connections.save(result.email, result.refreshToken);
      return Response.found(oauth.adminRedirect('connected').toString());
    } catch (_) {
      return Response.found(oauth.adminRedirect('failed').toString());
    }
  }

  Future<Map<String, dynamic>> _readJson(Request request) async {
    final body = await request.readAsString();
    if (body.length > 16384) throw const FormatException('Too large');
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    return decoded;
  }

  Future<Response> _priority(Request request, String id) async {
    final denied = _checkAdmin(request);
    if (denied != null) return denied;
    final body = await _readJson(request);
    final value = body['priority'];
    if (value is! int || value < 1 || value > 1000000) {
      return jsonReply(400, {'message': 'Informe uma prioridade valida.'});
    }
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      return jsonReply(400, {'message': 'ID invalido.'});
    }
    final item = await connections.changePriority(id, value);
    if (item == null) {
      return jsonReply(404, {'message': 'Conexao nao encontrada.'});
    }
    return jsonReply(200, {'connection': item.publicJson()});
  }

  Future<Response> _delete(Request request, String id) async {
    final denied = _checkAdmin(request);
    if (denied != null) return denied;
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      return jsonReply(400, {'message': 'ID invalido.'});
    }
    if (!await connections.delete(id)) {
      return jsonReply(404, {'message': 'Conexao nao encontrada.'});
    }
    return Response(204);
  }

  Future<Response> _sendLegacyVerification(Request request) async {
    final body = await _readJson(request);
    if (body['to'] is! String || body['verificationUrl'] is! String) {
      return jsonReply(400, {'message': 'Dados do e-mail ausentes.'});
    }
    await delivery.send(
      kind: 'verification',
      to: body['to'] as String,
      actionUrl: body['verificationUrl'] as String,
      eventId: DateTime.now().microsecondsSinceEpoch.toString(),
    );
    return jsonReply(200, {'message': 'E-mail de verificacao enviado.'});
  }
}
