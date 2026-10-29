import 'dart:convert';

import 'package:portal_contracts/portal_contracts.dart';
import 'package:portal_database/portal_database.dart';

import '../domain/registration.dart';

class PostgresRegistrationRepository implements RegistrationRepository {
  const PostgresRegistrationRepository(this.database, {this.clock});
  final DatabaseClient database;
  final DateTime Function()? clock;

  DateTime get now => (clock ?? DateTime.now)().toUtc();

  PendingRegistration _row(Map<String, dynamic> row) => PendingRegistration(
        id: row['id'].toString(),
        email: row['email'].toString(),
        passwordHash: row['password_hash'].toString(),
        expiresAt: (row['expires_at'] as DateTime).toUtc(),
        consumedAt: (row['consumed_at'] as DateTime?)?.toUtc(),
      );

  @override
  Future<PendingRegistration> request({
    required String requestId,
    required String email,
    required String passwordHash,
    required String tokenHash,
    required DateTime expiresAt,
  }) =>
      database.transaction((tx) async {
        // Keep exactly one pending request per normalized e-mail.
        // A fresh link invalidates an older still-unused link.
        await tx.query(
          'DELETE FROM email_verification_tokens '
          'WHERE email = @email AND consumed_at IS NULL',
          params: {'email': email},
        );
        final rows = await tx.query(
          'INSERT INTO email_verification_tokens '
          '(id, email, password_hash, token_hash, expires_at) '
          'VALUES (CAST(@id AS uuid), @email, @password, @token, @expiry) '
          'RETURNING id, email, password_hash, expires_at, consumed_at',
          params: {
            'id': requestId,
            'email': email,
            'password': passwordHash,
            'token': tokenHash,
            'expiry': expiresAt.toUtc(),
          },
        );
        await _addEvent(tx, PortalEventTypes.verificationRequested,
            {'requestId': requestId});
        return _row(rows.single);
      });

  @override
  Future<PendingRegistration?> findRequest(String requestId) async {
    final rows = await database.query(
      'SELECT id, email, password_hash, expires_at, consumed_at '
      'FROM email_verification_tokens WHERE id = CAST(@id AS uuid) LIMIT 1',
      params: {'id': requestId},
    );
    final result = rows.isEmpty ? null : _row(rows.first);
    return result != null && result.isValidAt(now) ? result : null;
  }

  @override
  Future<bool> verify(String tokenHash,
          Future<void> Function(PendingRegistration) create) =>
      database.transaction((tx) async {
        // SELECT FOR UPDATE serializes concurrent uses of the same token.
        final rows = await tx.query(
          'SELECT id, email, password_hash, expires_at, consumed_at '
          'FROM email_verification_tokens '
          'WHERE token_hash = @token FOR UPDATE',
          params: {'token': tokenHash},
        );
        if (rows.isEmpty) return false;
        final pending = _row(rows.single);
        if (!pending.isValidAt(now)) return false;

        // HTTP has a bounded timeout. Auth creation is idempotent across
        // retries after a failed local transaction.
        await create(pending);
        final updated = await tx.query(
          'UPDATE email_verification_tokens SET consumed_at = now() '
          'WHERE id = CAST(@id AS uuid) AND consumed_at IS NULL '
          'RETURNING id',
          params: {'id': pending.id},
        );
        if (updated.isEmpty) return false;
        await _addEvent(tx, PortalEventTypes.emailVerified,
            {'requestId': pending.id});
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
