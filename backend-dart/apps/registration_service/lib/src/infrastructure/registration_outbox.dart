import 'dart:async';
import 'dart:convert';

import 'package:portal_database/portal_database.dart';
import 'package:portal_events/portal_events.dart';

/// Publishes committed events only; never proxies HTTP through NATS.
class RegistrationOutbox {
  const RegistrationOutbox(this.database, this.events);

  final DatabaseClient database;
  final EventBus events;

  Future<int> flush() async {
    final rows = await database.query(
      'SELECT event_id, type, payload, occurred_at '
      'FROM event_outbox WHERE published_at IS NULL '
      'ORDER BY occurred_at LIMIT 20',
    );
    var count = 0;
    for (final row in rows) {
      final json = row['payload'];
      final payload = json is Map
          ? Map<String, dynamic>.from(json)
          : Map<String, dynamic>.from(jsonDecode(json.toString()) as Map);
      final eventId = row['event_id'].toString();
      final event = EventEnvelope(
        eventId: eventId,
        type: row['type'].toString(),
        schemaVersion: 1,
        source: 'registration-service',
        occurredAt: (row['occurred_at'] as DateTime).toUtc(),
        payload: payload,
      );
      await events.publish(event);
      await database.query(
        'UPDATE event_outbox SET published_at = now() '
        'WHERE event_id = CAST(@id AS uuid) AND published_at IS NULL',
        params: {'id': eventId},
      );
      count++;
    }
    return count;
  }
}

class RegistrationOutboxWorker {
  RegistrationOutboxWorker(this.outbox);
  final RegistrationOutbox outbox;
  Timer? _timer;
  bool _busy = false;

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      await outbox.flush();
    } catch (error) {
      print('[registration] NATS outbox retry: ' +
          error.runtimeType.toString());
    } finally {
      _busy = false;
    }
  }

  void start() {
    _timer ??= Timer.periodic(
        const Duration(seconds: 2), (_) => unawaited(_tick()));
    unawaited(_tick());
  }

  void stop() => _timer?.cancel();
}
