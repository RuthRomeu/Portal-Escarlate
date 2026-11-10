import 'package:postgres/postgres.dart';

abstract interface class DatabaseClient {
  Future<bool> ping();
  Future<List<Map<String, dynamic>>> query(String sql, {Map<String, dynamic> params = const {}});
  Future<T> transaction<T>(Future<T> Function(DatabaseClient tx) action);
  Future<void> close();
}

/// Parseia uma connection string PostgreSQL e cria um [Pool] com as
/// configurações corretas de SSL, ignorando o parâmetro da URL (que o
/// pacote `postgres` 3.x não respeita em [Pool.withUrl]).
Pool _createPool(String url) {
  final uri = Uri.parse(url);
  final params = uri.queryParameters;
  final sslModeStr = params['sslmode'] ?? 'prefer';

  final SslMode sslMode;
  switch (sslModeStr.toLowerCase()) {
    case 'disable':
      sslMode = SslMode.disable;
    case 'require':
      sslMode = SslMode.require;
    default:
      sslMode = SslMode.disable; // padrão seguro para dev local
  }

  final endpoint = Endpoint(
    host: uri.host.isEmpty ? 'localhost' : uri.host,
    port: uri.hasPort ? uri.port : 5432,
    database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'postgres',
    username: uri.userInfo.isNotEmpty ? Uri.decodeComponent(uri.userInfo.split(':').first) : null,
    password: uri.userInfo.contains(':') ? Uri.decodeComponent(uri.userInfo.split(':').skip(1).join(':')) : null,
  );

  return Pool.withEndpoints(
    [endpoint],
    settings: PoolSettings(
      sslMode: sslMode,
    ),
  );
}

class PostgresDatabase implements DatabaseClient {
  PostgresDatabase(String url) : _pool = _createPool(url);

  final Pool _pool;

  @override
  Future<bool> ping() async {
    await _pool.execute('SELECT 1');
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql,
      {Map<String, dynamic> params = const {}}) async {
    final result = await _pool.execute(Sql.named(sql), parameters: params);
    return result.map((row) => row.toColumnMap()).toList();
  }

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseClient tx) action) =>
      _pool.runTx((session) => action(_PostgresTransaction(session)));

  @override
  Future<void> close() => _pool.close();
}

class _PostgresTransaction implements DatabaseClient {
  _PostgresTransaction(this._session);
  final TxSession _session;

  @override
  Future<bool> ping() async {
    await _session.execute('SELECT 1');
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql,
      {Map<String, dynamic> params = const {}}) async {
    final result = await _session.execute(Sql.named(sql), parameters: params);
    return result.map((row) => row.toColumnMap()).toList();
  }

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseClient tx) action) =>
      throw UnsupportedError('Transações aninhadas não são suportadas.');

  @override
  Future<void> close() async =>
      throw UnsupportedError('Sessão gerenciada pela transação externa.');
}
