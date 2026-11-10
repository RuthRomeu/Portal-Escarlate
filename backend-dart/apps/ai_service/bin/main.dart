import 'dart:io';

import 'package:ai_service/ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:portal_database/portal_database.dart';
import 'package:portal_http/portal_http.dart';
import 'package:portal_http/session_verifier.dart';

Future<void> main() async {
  final env = Platform.environment;

  // Variáveis de ambiente obrigatórias.
  const required = [
    'DATABASE_URL',
    'PORTAL_INTERNAL_TOKEN',
    'AUTH_SECRET',
    'SECRETS_ENCRYPTION_KEY',
    'APP_URL',
  ];
  final missing = required.where((k) => (env[k] ?? '').isEmpty).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('[ai] Configuração ausente: ${missing.join(', ')}');
    exitCode = 78;
    return;
  }

  final db = PostgresDatabase(env['DATABASE_URL']!);
  final httpClient = http.Client();

  try {
    await db.ping();

    final cipher = SecretCipher(env['SECRETS_ENCRYPTION_KEY']!);
    final repo = PostgresAiConfigRepository(db, cipher);
    final openRouter = OpenRouterClient(
      httpClient: httpClient,
      appUrl: env['APP_URL']!,
    );
    final completionService = AiCompletionService(
      configRepository: repo,
      openRouter: openRouter,
    );
    final sessions = SessionVerifier(env['AUTH_SECRET']!);

    final api = AiApi(
      completionService: completionService,
      sessions: sessions,
      eventBus: null, // NATS opcional; ativar quando EVENT_BUS_ENABLED=true
      appUrl: env['APP_URL']!,
    );

    await runService(
      name: 'ai',
      port: 3004,
      registerRoutes: (router, _) => api.registerRoutes(router),
    );
  } catch (error) {
    stderr.writeln('[ai] Falha de inicialização: ${error.runtimeType}');
    httpClient.close();
    await db.close();
    rethrow;
  }
}
