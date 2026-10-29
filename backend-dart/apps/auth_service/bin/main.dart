import 'dart:io';

import 'package:auth_service/auth_service.dart';
import 'package:portal_core/portal_core.dart';
import 'package:portal_database/portal_database.dart';
import 'package:portal_http/portal_http.dart';

Future<void> main() async {
  final config = ServiceConfig(name: 'auth', defaultPort: 3001);
  final databaseUrl = config.databaseUrl;
  final internalToken = config.internalToken;
  final secret = Platform.environment['AUTH_SECRET'];

  if (databaseUrl == null || databaseUrl.isEmpty ||
      internalToken == null || internalToken.isEmpty ||
      secret == null || secret.isEmpty) {
    stderr.writeln('[auth] DATABASE_URL, PORTAL_INTERNAL_TOKEN e AUTH_SECRET '
        'são obrigatórios.');
    exitCode = 78;
    return;
  }

  final database = PostgresDatabase(databaseUrl);
  try {
    await database.ping();
    final api = AuthApi(
      repository: PostgresAuthRepository(database),
      passwords: Argon2Passwords(),
      sessions: SessionTokens(secret),
      secureCookies: Platform.environment['NODE_ENV'] == 'production',
      appUrl: Platform.environment['APP_URL'],
    );
    await runService(
        name: 'auth', port: 3001, registerRoutes: (router, _) => api.registerRoutes(router));
  } catch (error) {
    stderr.writeln('[auth] Falha ao iniciar: ' + error.runtimeType.toString());
    await database.close();
    rethrow;
  }
}
