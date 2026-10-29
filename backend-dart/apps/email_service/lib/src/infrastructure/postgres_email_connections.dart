import 'package:portal_database/portal_database.dart';

import '../domain/email_connection.dart';
import 'secret_cipher.dart';

class PostgresEmailConnections implements EmailConnectionRepository {
  const PostgresEmailConnections(this.db, this.cipher);
  final DatabaseClient db;
  final SecretCipher cipher;

  Future<EmailConnection> _decode(Map<String, dynamic> row) async {
    final stored = row['refresh_token'].toString();
    final token = stored.startsWith('enc:v1:')
        ? await cipher.decrypt(stored)
        : stored;
    // Node também aceita tokens legados não criptografados. Ao ler,
    // cifrar o valor sem sobrescrever alterações concorrentes.
    if (!stored.startsWith('enc:v1:') && token.isNotEmpty) {
      await db.query(
        'UPDATE email_connections SET refresh_token = @encrypted, '
        'updated_at = now() '
        'WHERE id = CAST(@id AS uuid) AND refresh_token = @old',
        params: {
          'id': row['id'].toString(),
          'old': stored,
          'encrypted': await cipher.encrypt(token),
        },
      );
    }
    return EmailConnection(
      id: row['id'].toString(),
      provider: row['provider'].toString(),
      email: row['email'].toString(),
      refreshToken: token,
      active: row['active'] == true,
      priority: (row['priority'] as num).toInt(),
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
    );
  }

  @override
  Future<List<EmailConnection>> list() async {
    final rows = await db.query(
      'SELECT * FROM email_connections ORDER BY priority ASC, created_at ASC',
    );
    return Future.wait(rows.map(_decode));
  }

  @override
  Future<EmailConnection?> active() async {
    final rows = await db.query(
      'SELECT * FROM email_connections WHERE active = true '
      'ORDER BY priority ASC, created_at ASC LIMIT 1',
    );
    return rows.isEmpty ? null : _decode(rows.first);
  }

  @override
  Future<EmailConnection> save(String email, String refreshToken,
      {int priority = 100}) async {
    final encoded = await cipher.encrypt(refreshToken);
    final rows = await db.query(
      'INSERT INTO email_connections '
      '(provider, email, refresh_token, active, priority) '
      "VALUES ('gmail', @email, @token, true, @priority) "
      'ON CONFLICT (email) DO UPDATE SET refresh_token = @token, '
      'active = true, priority = @priority, updated_at = now() '
      'RETURNING *',
      params: {
        'email': email.toLowerCase().trim(),
        'token': encoded,
        'priority': priority,
      },
    );
    return _decode(rows.single);
  }

  @override
  Future<EmailConnection?> changePriority(String id, int priority) async {
    final rows = await db.query(
      'UPDATE email_connections SET priority = @priority, updated_at = now() '
      'WHERE id = CAST(@id AS uuid) RETURNING *',
      params: {'id': id, 'priority': priority},
    );
    return rows.isEmpty ? null : _decode(rows.single);
  }

  @override
  Future<bool> delete(String id) async {
    final rows = await db.query(
      'DELETE FROM email_connections WHERE id = CAST(@id AS uuid) RETURNING id',
      params: {'id': id},
    );
    return rows.isNotEmpty;
  }
}
