import 'dart:convert';

import 'package:portal_contracts/portal_contracts.dart';
import 'package:portal_database/portal_database.dart';

import '../domain/auth_user.dart';

abstract interface class AuthRepository {
  Future<AuthUser?> findByEmail(String email);
  Future<AuthUser?> createUser(String email, String passwordHash);
  Future<AuthUser?> updatePassword(String email, String passwordHash);
}

class PostgresAuthRepository implements AuthRepository {
  const PostgresAuthRepository(this.database);
  final DatabaseClient database;

  AuthUser _fromRow(Map<String, dynamic> row) => AuthUser(
        id: row['id'].toString(),
        email: normalizeEmail(row['email'].toString()),
        role: row['role']?.toString() ?? 'user',
        passwordHash: row['password']?.toString(),
      );

  @override
  Future<AuthUser?> findByEmail(String email) async {
    final rows = await database.query(
      'SELECT id, email, role, password FROM users_2 '
      'WHERE email = @email LIMIT 1',
      params: {'email': normalizeEmail(email)},
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<AuthUser?> createUser(String email, String passwordHash) =>
      database.transaction((tx) async {
        final rows = await tx.query(
          'INSERT INTO users_2 (email, password, role) '
          "VALUES (@email, @hash, 'user') "
          'ON CONFLICT (email) DO NOTHING '
          'RETURNING id, email, role, password',
          params: {'email': normalizeEmail(email), 'hash': passwordHash},
        );
        if (rows.isEmpty) return null;
        final user = _fromRow(rows.first);
        await _recordEvent(tx, 'portal.auth.user_created.v1', {
          'userId': user.id,
          'role': user.role,
        });
        return user;
      });

  @override
  Future<AuthUser?> updatePassword(String email, String passwordHash) =>
      database.transaction((tx) async {
        final rows = await tx.query(
          'UPDATE users_2 SET password = @hash WHERE email = @email '
          'RETURNING id, email, role, password',
          params: {'email': normalizeEmail(email), 'hash': passwordHash},
        );
        if (rows.isEmpty) return null;
        final user = _fromRow(rows.first);
        await _recordEvent(tx, 'portal.auth.password_updated.v1', {
          'userId': user.id,
        });
        return user;
      });

  /// O evento permanece na outbox até um publicador confirmar o ACK NATS.
  /// Nunca armazenar hash de senha, tokens ou endereço IP no evento.
  Future<void> _recordEvent(DatabaseClient tx, String type,
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
