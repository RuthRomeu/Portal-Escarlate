import 'dart:async';
import 'dart:convert';

import 'package:portal_database/portal_database.dart';
import 'package:portal_events/portal_events.dart';

/// Publishes domain events to NATS after the DB transaction commits.
/// JetStream only carries opaque request IDs, not password reset URLs.
class RecoveryOutbox {
  const RecoveryOutbox(this.database, this.bus);

  final DatabaseClient database;
  final EventBus bus;

  Future<int> flush() async {
    final pending = await database.query(
      'SELECT event_id, type, payload, occurred_at '
      'FROM event_outbox WHERE published_at IS NULL '
      'ORDER BY occurred_at LIMIT 20',
    );
    var count = 0;
    for (final row in pending) {
      final json = row['payload'];
      final payload = json is Map
          ? Map<String, dynamic>.from(json)
          : Map<String, dynamic>.from(jsonDecode(json.toString()) as Map);
      final id = row['event_id'].toString();
      await bus.publish(EventEnvelope(
        eventId: id,
        type: row['type'].toString(),
        schemaVersion: 1,
        source: 'password-recovery-service',
        occurredAt: (row['occurred_at'] as DateTime).toUtc(),
        payload: payload,
      ));
      await database.query(
        'UPDATE event_outbox SET published_at = now() '
        'WHERE event_id = CAST(@id AS uuid) AND published_at IS NULL',
        params: {'id': id},
      );
      count++;
    }
    return count;
  }
}

class RecoveryOutboxWorker {
  RecoveryOutboxWorker(this.outbox);
  final RecoveryOutbox outbox;
  Timer? _timer;
  bool _running = false;

  Future<void> _tick() async {
    if (_running) return;
    _running = true;
    try {
      await outbox.flush();
    } catch (error) {
      print('[password-recovery] outbox retry: ' +
          error.runtimeType.toString());
    } finally {
      _running = false;
    }
  }

  void start() {
    _timer ??= Timer.periodic(
      const Duration(seconds: 2), (_) => unawaited(_tick()));
    unawaited(_tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
