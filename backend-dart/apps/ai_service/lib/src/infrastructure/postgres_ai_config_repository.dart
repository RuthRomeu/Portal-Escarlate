import 'package:portal_database/portal_database.dart';

import '../domain/ai_config.dart';
import 'secret_cipher.dart';

/// Repositório de configurações de IA lendo das tabelas [ai_api_keys] /
/// [ai_models]. Faz lazy-encryption das chaves ainda em texto-plano, igual
/// ao comportamento do config-repo.js do Node.js.
///
/// Fallback: se as tabelas primárias não existirem (Postgres error 42P01),
/// recai nas tabelas legadas [ai_summary_api_keys] / [ai_summary_models].
class PostgresAiConfigRepository implements AiConfigRepository {
  const PostgresAiConfigRepository(this.db, this.cipher);

  final DatabaseClient db;
  final SecretCipher cipher;

  @override
  Future<List<AiConfig>> listActive() async {
    try {
      return await _loadFromTables('ai_api_keys', 'ai_models');
    } on Object catch (e) {
      if (_isUndefinedTable(e)) {
        return _loadFromTables('ai_summary_api_keys', 'ai_summary_models');
      }
      rethrow;
    }
  }

  Future<List<AiConfig>> _loadFromTables(
      String keysTable, String modelsTable) async {
    final rows = await db.query(
      'SELECT '
      '  keys.id          AS api_key_id, '
      '  keys.provider, '
      '  keys.label, '
      '  keys.api_key, '
      '  models.model '
      'FROM $keysTable keys '
      'JOIN $modelsTable models '
      '  ON models.api_key_id = keys.id '
      'WHERE keys.active = true '
      '  AND models.active = true '
      'ORDER BY '
      '  keys.priority ASC, '
      '  keys.created_at ASC, '
      '  models.priority ASC, '
      '  models.created_at ASC',
    );

    final configs = <AiConfig>[];
    // Cache de chaves decifradas para evitar chamadas duplicadas de criptografia.
    final decryptedCache = <String, String?>{};

    for (final row in rows) {
      final keyId = row['api_key_id'].toString();
      var storedKey = row['api_key'].toString();

      // Lazy-encrypt: se a chave não tem o prefixo, cifra e atualiza no banco.
      if (!cipher.isEncrypted(storedKey)) {
        try {
          final encrypted = await cipher.encrypt(storedKey);
          await db.query(
            'UPDATE $keysTable SET api_key = @encrypted WHERE id = CAST(@id AS uuid)',
            params: {'id': keyId, 'encrypted': encrypted},
          );
          storedKey = encrypted;
        } catch (_) {
          // Falha na criptografia — continua com a chave original por ora.
        }
      }

      if (!decryptedCache.containsKey(keyId)) {
        try {
          decryptedCache[keyId] = await cipher.decrypt(storedKey);
        } catch (e) {
          // Loga apenas o tipo de erro — nunca o valor da chave.
          print('[ai-service] Ignorando chave de API ilegível: keyId=$keyId');
          decryptedCache[keyId] = null;
        }
      }

      final decryptedKey = decryptedCache[keyId];
      if (decryptedKey == null || decryptedKey.isEmpty) continue;

      // Agrupa modelos por configuração de chave.
      final existing = configs.where((c) => c.apiKeyId == keyId);
      if (existing.isEmpty) {
        configs.add(AiConfig(
          apiKeyId: keyId,
          provider: row['provider'].toString(),
          label: row['label']?.toString(),
          apiKey: decryptedKey,
          models: [row['model'].toString()],
        ));
      } else {
        existing.first.models.add(row['model'].toString());
      }
    }

    return configs;
  }

  /// Verifica se o erro do postgres corresponde a "tabela não encontrada" (42P01).
  static bool _isUndefinedTable(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('42p01') ||
        msg.contains('undefined_table') ||
        msg.contains('does not exist');
  }
}
