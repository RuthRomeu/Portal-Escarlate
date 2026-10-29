import 'dart:convert';

import 'package:portal_contracts/portal_contracts.dart';
import 'package:portal_database/portal_database.dart';

import '../domain/email_connection.dart';

class PostgresEmailEvents implements EmailEventRepository {
  const PostgresEmailEvents(this.db);
  final DatabaseClient db;

  @override
  Future<EventClaim> claim(String id, String type) async {
    final claimed = await db.query(
      'INSERT INTO event_inbox (event_id, type, status, claimed_until) '
      "VALUES (CAST(@id AS uuid), @type, 'processing', "
      "now() + interval '5 minutes') "
      'ON CONFLICT (event_id) DO UPDATE SET '
      "status = 'processing', claimed_until = now() + interval '5 minutes' "
      "WHERE event_inbox.status = 'pending' OR "
      "(event_inbox.status = 'processing' AND "
      'event_inbox.claimed_until < now()) RETURNING event_id',
      params: {'id': id, 'type': type},
    );
    if (claimed.isNotEmpty) return EventClaim.claimed;
    final rows = await db.query(
      'SELECT status FROM event_inbox WHERE event_id = CAST(@id AS uuid)',
      params: {'id': id},
    );
    return rows.isNotEmpty && rows.first['status'] == 'processed'
        ? EventClaim.processed
        : EventClaim.busy;
  }

  @override
  Future<void> complete(String eventId, String eventType,
      String requestId) => db.transaction((tx) async {
    await tx.query(
      "UPDATE event_inbox SET status = 'processed', "
      'processed_at = now(), claimed_until = NULL '
      'WHERE event_id = CAST(@id AS uuid)',
      params: {'id': eventId},
    );
    await tx.query(
      'INSERT INTO event_outbox (event_id, type, payload) '
      'VALUES (CAST(@id AS uuid), @type, CAST(@payload AS jsonb))',
      params: {
        'id': newEventId(),
        'type': 'portal.email.delivery_succeeded.v1',
        'payload': jsonEncode({
          'requestId': requestId,
          'sourceEventId': eventId,
          'sourceEventType': eventType,
        }),
      },
    );
  });

  @override
  Future<void> release(String eventId) async {
    await db.query(
      "UPDATE event_inbox SET status = 'pending', claimed_until = NULL "
      'WHERE event_id = CAST(@id AS uuid) AND status = @status',
      params: {'id': eventId, 'status': 'processing'},
    );
  }
}
