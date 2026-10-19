import 'dart:io';
import 'package:portal_events/portal_events.dart';

Future<void> main() async {
  final bus = NatsJetStreamEventBus(
    Platform.environment['NATS_URL'] ?? 'nats://127.0.0.1:4222',
  );
  try {
    await bus.connect();
    final event = EventEnvelope.create(type: 'portal.demo.ping',
      source: 'smoke-publisher', payload: {'message': 'ping'});
    await bus.publish(event);
    stdout.writeln('Publicado evento ${event.eventId}');
  } finally {
    await bus.close();
  }
}
