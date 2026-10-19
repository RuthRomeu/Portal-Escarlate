import 'dart:async';
import 'dart:convert';

import 'package:dart_nats/dart_nats.dart' as nats;
import 'package:portal_contracts/portal_contracts.dart';

export 'package:portal_contracts/portal_contracts.dart';

typedef EventHandler = Future<void> Function(EventEnvelope event);

abstract interface class EventBus {
  Future<void> connect();
  Future<void> publish(EventEnvelope event);
  Future<void> subscribe({
    required String subject,
    required String durableName,
    required EventHandler handler,
  });
  Future<void> close();
}

/// Somente eventos interserviços. Não usar o barramento como RPC HTTP.
class NatsJetStreamEventBus implements EventBus {
  NatsJetStreamEventBus(this.url);

  static const streamName = 'PORTAL_EVENTS';
  final String url;
  final nats.Client _client = nats.Client();
  late final nats.JetStream _jetStream;
  final List<Future<void>> _workers = [];
  bool _running = false;

  @override
  Future<void> connect() async {
    if (_running) return;
    await _client.connect(Uri.parse(url), retry: true, retryCount: 5);
    await _client.waitUntilConnected();
    _jetStream = _client.jetStream();
    await _jetStream.createOrUpdateStream(nats.StreamConfig(
      name: streamName,
      subjects: ['portal.>'],
      storage: 'file',
      retention: 'limits',
      maxAge: const Duration(days: 7),
    ));
    _running = true;
  }

  @override
  Future<void> publish(EventEnvelope event) async {
    if (!_running) throw StateError('Conecte o barramento antes de publicar.');
    if (!event.type.startsWith('portal.')) {
      throw ArgumentError.value(event.type, 'type', 'Evento deve começar com portal.');
    }
    await _jetStream.publishString(
      event.type, jsonEncode(event.toJson()),
      opts: nats.PubOpts(msgId: event.eventId),
    );
  }

  @override
  Future<void> subscribe({
    required String subject,
    required String durableName,
    required EventHandler handler,
  }) async {
    if (!_running) throw StateError('Conecte o barramento antes de consumir.');
    if (!subject.startsWith('portal.')) throw ArgumentError.value(subject, 'subject');
    final consumer = await _jetStream.createOrUpdateConsumer(
      streamName,
      nats.ConsumerConfig(durable: durableName, filterSubject: subject,
        ackPolicy: 'explicit'),
    );
    // Pull consumer durável: o cursor fica no NATS, mesmo após reiniciar o processo.
    _workers.add(_consume(consumer, handler));
  }

  Future<void> _consume(nats.Consumer<dynamic> consumer, EventHandler handler) async {
    while (_running) {
      try {
        final batch = await consumer.fetch(batch: 1, timeout: const Duration(seconds: 2));
        for (final message in batch) {
          try {
            final decoded = jsonDecode(message.string) as Map<String, dynamic>;
            await handler(EventEnvelope.fromJson(decoded));
            await message.ackSync();
          } catch (error) {
            // Reentrega exige idempotência por eventId quando houver regras de negócio.
            stderrLog('Erro processando evento: $error');
            message.nak();
          }
        }
      } catch (error) {
        if (_running) {
          if (error is! TimeoutException) stderrLog('Erro consumindo NATS: $error');
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
    }
  }

  @override
  Future<void> close() async {
    _running = false;
    await Future.wait(_workers);
    await _client.close();
  }
}

void stderrLog(String message) => print('[event-bus] $message');
