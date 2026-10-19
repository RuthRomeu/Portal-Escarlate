import 'package:postgres/postgres.dart';

abstract interface class DatabaseClient {
  Future<bool> ping();
  Future<List<Map<String, dynamic>>> query(String sql, {Map<String, dynamic> params = const {}});
  Future<T> transaction<T>(Future<T> Function(DatabaseClient tx) action);
  Future<void> close();
}

class PostgresDatabase implements DatabaseClient {
  PostgresDatabase(String url) : _pool = Pool.withUrl(url);

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
