import 'dart:convert';

import 'package:email_service/email_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_events/portal_events.dart';
import 'package:test/test.dart';

class FakeBus implements EventBus {
  final subjects = <String>[];
  @override
  Future<void> connect() async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> publish(EventEnvelope event) async {}
  @override
  Future<void> subscribe({
    required String subject,
    required String durableName,
    required EventHandler handler,
  }) async {
    subjects.add(subject);
  }
}

class FakeInbox implements EmailEventRepository {
  final processed = <String>{};
  @override
  Future<EventClaim> claim(String id, String type) async =>
      processed.contains(id) ? EventClaim.processed : EventClaim.claimed;
  @override
  Future<void> complete(String id, String type, String requestId) async {
    processed.add(id);
  }
  @override
  Future<void> release(String id) async {}
}

class FakeSender implements EmailDelivery {
  var sent = 0;
  @override
  Future<void> send({
    required String kind,
    required String to,
    required String actionUrl,
    required String eventId,
  }) async {
    expect(kind, 'verification');
    expect(to, 'user@example.com');
    expect(actionUrl, 'https://example.com/verify-email?code=secret');
    sent++;
  }
}

void main() {
  test('somente requestId vai no evento, sem link secreto', () async {
    const id = '11111111-1111-4111-8111-111111111111';
    final payload = {'requestId': id};
    final event = EventEnvelope.create(
      type: EmailEventHandler.verification,
      source: 'registration-service',
      payload: payload,
    );
    expect(jsonEncode(event.toJson()), isNot(contains('code=')));
    final seen = <Uri>[];
    final client = MockClient((request) async {
      seen.add(request.url);
      expect(request.headers['x-internal-token'], 'service-secret');
      return http.Response(jsonEncode({
        'to': 'user@example.com',
        'actionUrl': 'https://example.com/verify-email?code=secret',
      }), 200);
    });
    final bus = FakeBus();
    final inbox = FakeInbox();
    final sender = FakeSender();
    final service = EmailEventHandler(
      bus: bus, inbox: inbox, delivery: sender, client: client,
      registrationUrl: Uri.parse('http://registration:3003'),
      recoveryUrl: Uri.parse('http://recovery:3009'),
      internalToken: 'service-secret',
    );
    await service.subscribe();
    expect(bus.subjects, hasLength(2));
    await service.process(event);
    await service.process(event);
    expect(sender.sent, 1);
    expect(seen.single.path,
        '/internal/registration/email-requests/' + id);
  });
}
