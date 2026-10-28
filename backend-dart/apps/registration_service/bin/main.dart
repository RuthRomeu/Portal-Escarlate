import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:portal_core/portal_core.dart';
import 'package:portal_database/portal_database.dart';
import 'package:portal_events/portal_events.dart';
import 'package:portal_http/portal_http.dart';
import 'package:registration_service/registration_service.dart';

Future<void> main() async {
  final config = ServiceConfig(name: 'registration', defaultPort: 3003);
  final env = Platform.environment;
  final missing = [
    'DATABASE_URL',
    'PORTAL_INTERNAL_TOKEN',
    'AUTH_SERVICE_URL',
    'APP_URL',
    'REGISTRATION_TOKEN_SECRET',
  ].where((name) => (env[name] ?? '').isEmpty).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('[registration] Configuração ausente: ' +
        missing.join(', '));
    exitCode = 78;
    return;
  }

  final db = PostgresDatabase(env['DATABASE_URL']!);
  final client = http.Client();
  NatsJetStreamEventBus? bus;
  RegistrationOutboxWorker? worker;
  try {
    await db.ping();
    final app = RegistrationApplication(
      repository: PostgresRegistrationRepository(db),
      auth: HttpAuthRegistrationClient(
        client,
        Uri.parse(env['AUTH_SERVICE_URL']!),
        env['PORTAL_INTERNAL_TOKEN']!,
      ),
      hasher: Argon2RegistrationHasher(),
      tokens: RegistrationTokens(env['REGISTRATION_TOKEN_SECRET']!),
      appUrl: Uri.parse(env['APP_URL']!),
    );
    // Outbox publishing is opt-in until the downstream e-mail consumer is
    // configured. No registration token or action URL enters NATS.
    if (env['REGISTRATION_EVENTS_ENABLED'] == 'true') {
      bus = NatsJetStreamEventBus(config.natsUrl);
      await bus.connect();
      worker = RegistrationOutboxWorker(RegistrationOutbox(db, bus));
      worker.start();
    }
    await runService(
      name: 'registration',
      port: 3003,
      registerRoutes: (router, _) =>
          RegistrationApi(app).registerRoutes(router),
    );
  } catch (error) {
    stderr.writeln('[registration] Falha ao iniciar: ' +
        error.runtimeType.toString());
    worker?.stop();
    if (bus != null) await bus.close();
    client.close();
    await db.close();
    rethrow;
  }
}
