import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/email_connection.dart';
import '../infrastructure/google_oauth.dart';

abstract interface class EmailDelivery {
  Future<void> send({
    required String kind,
    required String to,
    required String actionUrl,
    required String eventId,
  });
}

class GmailDelivery implements EmailDelivery {
  GmailDelivery(this.connections, this.oauth, this.client,
      {Uri? endpoint, this.senderName = 'Portal Escarlate'})
      : _endpoint = endpoint ??
            Uri.parse(
                'https://gmail.googleapis.com/gmail/v1/users/me/messages/send');

  final EmailConnectionRepository connections;
  final GoogleOAuth oauth;
  final http.Client client;
  final Uri _endpoint;
  final String senderName;

  @override
  Future<void> send({
    required String kind,
    required String to,
    required String actionUrl,
    required String eventId,
  }) async {
    final link = Uri.tryParse(actionUrl);
    final application = Uri.tryParse(oauth.appUrl);
    final validEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(to);
    final validId = RegExp(r'^[a-zA-Z0-9-]{1,64}$').hasMatch(eventId);
    if ((kind != 'verification' && kind != 'recovery') ||
        !validEmail ||
        !validId ||
        link == null ||
        !link.hasScheme ||
        !link.hasAuthority ||
        application == null ||
        !application.hasScheme ||
        !application.hasAuthority ||
        link.origin != application.origin ||
        (link.scheme != 'https' && link.host != 'localhost')) {
      throw const FormatException('Solicitação de e-mail inválida');
    }

    final connection = await connections.active();
    if (connection == null || connection.provider != 'gmail') {
      throw StateError('Nenhuma conexão Gmail ativa');
    }

    final access = await oauth.refresh(connection.refreshToken);
    final mime = buildMime(
      sender: connection.email,
      to: to,
      senderName: senderName,
      kind: kind,
      actionUrl: actionUrl,
      eventId: eventId,
    );
    final raw = base64Url.encode(utf8.encode(mime)).replaceAll('=', '');
    final response = await client
        .post(_endpoint,
            headers: {
              'authorization': 'Bearer ' + access,
              'content-type': 'application/json',
            },
            body: jsonEncode({'raw': raw}))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Gmail HTTP ' + response.statusCode.toString());
    }
  }
}

String buildMime({
  required String sender,
  required String to,
  required String senderName,
  required String kind,
  required String actionUrl,
  required String eventId,
}) {
  final subject = kind == 'verification'
      ? 'Confirme seu e-mail para concluir seu cadastro'
      : 'Redefina sua senha do Portal Escarlate';
  final heading = kind == 'verification'
      ? 'Confirme seu e-mail'
      : 'Redefina sua senha';
  final text = heading +
      '\n\nEste link expira em 5 minutos:\n' +
      actionUrl +
      '\n\nSe nao solicitou, ignore esta mensagem.';
  final safeUrl = actionUrl
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
  final html = '<html><body style="font-family:Arial,sans-serif">' +
      '<h1>' + heading + '</h1>' +
      '<p>Este link expira em 5 minutos.</p>' +
      '<p><a href="' + safeUrl + '">' + heading + '</a></p>' +
      '<p>Se nao solicitou, ignore esta mensagem.</p>' +
      '</body></html>';
  final boundary = 'portal-' + eventId;
  final senderHeader = '=?UTF-8?B?' +
      base64.encode(utf8.encode(senderName)) + '?= <' + sender + '>';
  final encodedSubject =
      '=?UTF-8?B?' + base64.encode(utf8.encode(subject)) + '?=';

  return [
    'From: ' + senderHeader,
    'To: ' + to,
    'Subject: ' + encodedSubject,
    'Message-ID: <' + eventId + '@portal-escarlate.local>',
    'MIME-Version: 1.0',
    'Content-Type: multipart/alternative; boundary="' + boundary + '"',
    '',
    '--' + boundary,
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: base64',
    '',
    base64.encode(utf8.encode(text)),
    '--' + boundary,
    'Content-Type: text/html; charset=UTF-8',
    'Content-Transfer-Encoding: base64',
    '',
    base64.encode(utf8.encode(html)),
    '--' + boundary + '--',
    '',
  ].join('\r\n');
}
