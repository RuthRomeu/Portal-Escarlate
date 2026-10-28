import 'dart:convert';

import 'package:portal_contracts/portal_contracts.dart';
import 'package:portal_database/portal_database.dart';

import '../domain/recovery.dart';

class PostgresRecoveryRepository implements RecoveryRepository {
  const PostgresRecoveryRepository(this.database, {this.clock});

  final DatabaseClient database;
  final DateTime Function()? clock;

  DateTime get now => (clock ?? DateTime.now)().toUtc();

  PendingRecovery _fromRow(Map<String, dynamic> row) => PendingRecovery(
        id: row['id'].toString(),
        email: row['email'].toString(),
        expiresAt: (row['expires_at'] as DateTime).toUtc(),
        consumedAt: (row['consumed_at'] as DateTime?)?.toUtc(),
      );

  @override
  Future<PendingRecovery> request({
    required String requestId,
    required String email,
    required String tokenHash,
    required DateTime expiresAt,
  }) =>
      database.transaction((tx) async {
        // A new request invalidates all previous unconsumed tokens for email.
        await tx.query(
          'DELETE FROM password_recovery_tokens '
          'WHERE email = @email AND consumed_at IS NULL',
          params: {'email': email},
        );
        final rows = await tx.query(
          'INSERT INTO password_recovery_tokens '
          '(id, email, token_hash, expires_at) '
          'VALUES (CAST(@id AS uuid), @email, @hash, @expiry) '
          'RETURNING id, email, expires_at, consumed_at',
          params: {
            'id': requestId,
            'email': email,
            'hash': tokenHash,
            'expiry': expiresAt.toUtc(),
          },
        );
        await _addEvent(tx, PortalEventTypes.passwordRecoveryRequested, {
          'requestId': requestId,
        });
        return _fromRow(rows.single);
      });

  @override
  Future<PendingRecovery?> findRequest(String requestId) async {
    final rows = await database.query(
      'SELECT id, email, expires_at, consumed_at '
      'FROM password_recovery_tokens '
      'WHERE id = CAST(@id AS uuid) LIMIT 1',
      params: {'id': requestId},
    );
    final record = rows.isEmpty ? null : _fromRow(rows.single);
    return record != null && record.isValidAt(now) ? record : null;
  }

  @override
  Future<bool> reset(
    String tokenHash,
    Future<void> Function(PendingRecovery) changePassword,
  ) =>
      database.transaction((tx) async {
        // The lock serializes concurrent resets with the same token.
        final rows = await tx.query(
          'SELECT id, email, expires_at, consumed_at '
          'FROM password_recovery_tokens '
          'WHERE token_hash = @hash FOR UPDATE',
          params: {'hash': tokenHash},
        );
        if (rows.isEmpty) return false;
        final pending = _fromRow(rows.single);
        if (!pending.isValidAt(now)) return false;

        // Auth must confirm success BEFORE the local token is consumed.
        // If HTTP fails, the transaction rolls back, preserving the token.
        await changePassword(pending);
        final updated = await tx.query(
          'UPDATE password_recovery_tokens SET consumed_at = now() '
          'WHERE id = CAST(@id AS uuid) AND consumed_at IS NULL '
          'AND expires_at > now() RETURNING id',
          params: {'id': pending.id},
        );
        if (updated.isEmpty) return false;
        await _addEvent(tx, PortalEventTypes.passwordReset, {
          'requestId': pending.id,
        });
        return true;
      });

  Future<void> _addEvent(DatabaseClient tx, String type,
      Map<String, String> payload) async {
    await tx.query(
      'INSERT INTO event_outbox (event_id, type, payload) '
      'VALUES (CAST(@id AS uuid), @type, CAST(@payload AS jsonb))',
      params: {
        'id': newEventId(),
        'type': type,
        'payload': jsonEncode(payload),
      },
    );
  }
}
