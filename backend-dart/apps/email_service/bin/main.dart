import 'dart:io';

import 'package:email_service/email_service.dart';
import 'package:http/http.dart' as http;
import 'package:portal_core/portal_core.dart';
import 'package:portal_database/portal_database.dart';
import 'package:portal_events/portal_events.dart';
import 'package:portal_http/portal_http.dart';
import 'package:portal_http/session_verifier.dart';

Future<void> main() async {
  final config = ServiceConfig(name: 'email', defaultPort: 3005);
  final env = Platform.environment;
  final required = [
    'DATABASE_URL',
    'PORTAL_INTERNAL_TOKEN',
    'AUTH_SECRET',
    'SECRETS_ENCRYPTION_KEY',
    'GOOGLE_CLIENT_ID',
    'GOOGLE_CLIENT_SECRET',
    'GOOGLE_REDIRECT_URI',
    'APP_URL',
  ];
  final missing = required.where((key) => (env[key] ?? '').isEmpty).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('[email] Configuração ausente: ' + missing.join(', '));
    exitCode = 78;
    return;
  }

  final db = PostgresDatabase(env['DATABASE_URL']!);
  final client = http.Client();
  NatsJetStreamEventBus? bus;
  try {
    await db.ping();
    final connections =
        PostgresEmailConnections(db, SecretCipher(env['SECRETS_ENCRYPTION_KEY']!));
    final oauth = GoogleOAuth(
      client: client,
      clientId: env['GOOGLE_CLIENT_ID']!,
      clientSecret: env['GOOGLE_CLIENT_SECRET']!,
      redirectUri: env['GOOGLE_REDIRECT_URI']!,
      stateSecret: env['AUTH_SECRET']!,
      appUrl: env['APP_URL']!,
    );
    final delivery = GmailDelivery(connections, oauth, client);
    final api = EmailApi(
        connections, oauth, delivery, SessionVerifier(env['AUTH_SECRET']!));

    // Habilitar quando Registration/Recovery fornecerem os endpoints internos
    // que resolvem requestId. Até lá, NATS não recebe payloads secretos.
    if (env['EMAIL_EVENTS_ENABLED'] == 'true') {
      bus = NatsJetStreamEventBus(config.natsUrl);
      await bus.connect();
      final consumer = EmailEventHandler(
        bus: bus,
        inbox: PostgresEmailEvents(db),
        delivery: delivery,
        client: client,
        registrationUrl: Uri.parse(env['REGISTRATION_SERVICE_URL'] ??
            'http://127.0.0.1:3003'),
        recoveryUrl: Uri.parse(env['PASSWORD_RECOVERY_SERVICE_URL'] ??
            'http://127.0.0.1:3009'),
        internalToken: env['PORTAL_INTERNAL_TOKEN']!,
      );
      await consumer.subscribe();
    }

    await runService(
      name: 'email',
      port: 3005,
      registerRoutes: (router, _) => api.registerRoutes(router),
    );
  } catch (error) {
    stderr.writeln('[email] Falha de inicialização: ' +
        error.runtimeType.toString());
    if (bus != null) await bus.close();
    client.close();
    await db.close();
    rethrow;
  }
}
