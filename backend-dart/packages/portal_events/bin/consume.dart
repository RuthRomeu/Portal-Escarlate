import 'dart:async';
import 'dart:io';
import 'package:portal_events/portal_events.dart';

Future<void> main() async {
  final bus = NatsJetStreamEventBus(
    Platform.environment['NATS_URL'] ?? 'nats://127.0.0.1:4222',
  );
  await bus.connect();
  await bus.subscribe(subject: 'portal.demo.ping', durableName: 'portal_demo_receiver',
    handler: (event) async => stdout.writeln('Consumido ${event.eventId}: ${event.payload}'));
  stdout.writeln('Aguardando eventos portal.demo.ping...');
  final done = Completer<void>();
  ProcessSignal.sigint.watch().listen((_) { if (!done.isCompleted) done.complete(); });
  ProcessSignal.sigterm.watch().listen((_) { if (!done.isCompleted) done.complete(); });
  await done.future;
  await bus.close();
}
