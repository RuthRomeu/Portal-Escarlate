import 'package:portal_contracts/portal_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('serializa e recupera um evento com payload', () {
    final event = EventEnvelope.create(type: 'portal.demo.ping', source: 'test',
      payload: {'value': 1}, correlationId: 'cor-1');
    final restored = EventEnvelope.fromJson(event.toJson());
    expect(restored.eventId, event.eventId);
    expect(restored.type, 'portal.demo.ping');
    expect(restored.payload['value'], 1);
    expect(restored.correlationId, 'cor-1');
    expect(restored.eventId.length, 36);
  });
}
