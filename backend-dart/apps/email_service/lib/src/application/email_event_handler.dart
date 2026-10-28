import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:portal_events/portal_events.dart';

import '../domain/email_connection.dart';
import 'gmail_delivery.dart';

/// Somente o requestId trafega no NATS; tokens e links ficam fora do barramento.
class EmailEventHandler {
  const EmailEventHandler({
    required this.bus,
    required this.inbox,
    required this.delivery,
    required this.client,
    required this.registrationUrl,
    required this.recoveryUrl,
    required this.internalToken,
  });

  final EventBus bus;
  final EmailEventRepository inbox;
  final EmailDelivery delivery;
  final http.Client client;
  final Uri registrationUrl;
  final Uri recoveryUrl;
  final String internalToken;

  static const verification = 'portal.registration.verification_requested.v1';
  static const recovery = 'portal.password_recovery.requested.v1';

  Future<void> subscribe() async {
    await bus.subscribe(
      subject: verification,
      durableName: 'email-registration-v1',
      handler: process,
    );
    await bus.subscribe(
      subject: recovery,
      durableName: 'email-recovery-v1',
      handler: process,
    );
  }

  Future<void> process(EventEnvelope event) async {
    if (event.schemaVersion != 1 ||
        (event.type != verification && event.type != recovery)) {
      throw const FormatException('Evento não suportado');
    }
    if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(event.eventId)) {
      throw const FormatException('eventId inválido');
    }
    final requestId = event.payload['requestId'];
    if (requestId is! String ||
        !RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(requestId)) {
      throw const FormatException('requestId inválido');
    }

    final claimed = await inbox.claim(event.eventId, event.type);
    if (claimed == EventClaim.processed) return;
    if (claimed == EventClaim.busy) {
      throw StateError('Evento em processamento');
    }

    try {
      final isRegistration = event.type == verification;
      final service = isRegistration ? registrationUrl : recoveryUrl;
      final endpoint = isRegistration
          ? '/internal/registration/email-requests/'
          : '/internal/password-recovery/email-requests/';
      final response = await client.get(
        service.resolve(endpoint + requestId),
        headers: {'x-internal-token': internalToken},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw StateError('Solicitação de e-mail indisponível');
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> ||
          data['to'] is! String ||
          data['actionUrl'] is! String) {
        throw const FormatException('Dados de e-mail inválidos');
      }
      await delivery.send(
        kind: isRegistration ? 'verification' : 'recovery',
        to: data['to'] as String,
        actionUrl: data['actionUrl'] as String,
        eventId: event.eventId,
      );
      await inbox.complete(event.eventId, event.type, requestId);
    } catch (_) {
      await inbox.release(event.eventId);
      rethrow;
    }
  }
}
