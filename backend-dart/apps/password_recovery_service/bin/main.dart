import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:password_recovery_service/password_recovery_service.dart';
import 'package:portal_core/portal_core.dart';
import 'package:portal_database/portal_database.dart';
import 'package:portal_events/portal_events.dart';
import 'package:portal_http/portal_http.dart';

Future<void> main() async {
  final config = ServiceConfig(name: 'password-recovery', defaultPort: 3009);
  final env = Platform.environment;
  final missing = [
    'DATABASE_URL',
    'PORTAL_INTERNAL_TOKEN',
    'AUTH_SERVICE_URL',
    'APP_URL',
    'PASSWORD_RECOVERY_TOKEN_SECRET',
  ].where((key) => (env[key] ?? '').isEmpty).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('[password-recovery] Configuracao ausente: ' +
        missing.join(', '));
    exitCode = 78;
    return;
  }

  final database = PostgresDatabase(env['DATABASE_URL']!);
  final httpClient = http.Client();
  NatsJetStreamEventBus? bus;
  RecoveryOutboxWorker? worker;
  try {
    await database.ping();
    final app = RecoveryApplication(
      repository: PostgresRecoveryRepository(database),
      auth: HttpRecoveryAuthClient(
        httpClient, Uri.parse(env['AUTH_SERVICE_URL']!),
        env['PORTAL_INTERNAL_TOKEN']!,
      ),
      tokens: RecoveryTokens(env['PASSWORD_RECOVERY_TOKEN_SECRET']!),
      appUrl: Uri.parse(env['APP_URL']!),
    );

    // Events are opt-in until Gmail/NATS integration is configured.
    if (env['PASSWORD_RECOVERY_EVENTS_ENABLED'] == 'true') {
      bus = NatsJetStreamEventBus(config.natsUrl);
      await bus.connect();
      worker = RecoveryOutboxWorker(RecoveryOutbox(database, bus));
      worker.start();
    }

    await runService(
      name: 'password-recovery',
      port: 3009,
      registerRoutes: (router, _) => RecoveryApi(app).registerRoutes(router),
    );
  } catch (error) {
    stderr.writeln('[password-recovery] startup error: ' +
        error.runtimeType.toString());
    worker?.stop();
    if (bus != null) await bus.close();
    httpClient.close();
    await database.close();
    rethrow;
  }
}
