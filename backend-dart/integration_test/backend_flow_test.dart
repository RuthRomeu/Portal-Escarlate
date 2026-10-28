import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:email_service/email_service.dart';
import 'package:http/http.dart' as http;
import 'package:portal_database/portal_database.dart';
import 'package:portal_events/portal_events.dart';
import 'package:test/test.dart';

class _FakeGmail implements EmailDelivery {
  final confirmation = Completer<Uri>();
  final recovery = Completer<Uri>();
  final deliveries = <String>[];

  @override
  Future<void> send({
    required String kind, required String to,
    required String actionUrl, required String eventId,
  }) async {
    final url = Uri.parse(actionUrl);
    if (to.isEmpty || url.queryParameters['code'] == null) {
      throw StateError('Invalid internal email payload');
    }
    deliveries.add(kind);
    if (kind == 'verification' && !confirmation.isCompleted) {
      confirmation.complete(url);
    } else if (kind == 'recovery' && !recovery.isCompleted) {
      recovery.complete(url);
    }
  }
}

Future<void> _ready(http.Client client, int port) async {
  final until = DateTime.now().add(const Duration(seconds: 50));
  while (DateTime.now().isBefore(until)) {
    try {
      final response = await client.get(
        Uri.parse('http://127.0.0.1:$port/health/live'),
      ).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) return;
    } catch (_) {
      // Executable may still be compiling.
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw StateError('Service on port $port never became healthy');
}

Future<Process> _launch(String app, int port, String? databaseUrl,
    Map<String, String> settings, http.Client client) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'apps/$app/bin/main.dart'],
    workingDirectory: Directory.current.path,
    environment: {
      ...Platform.environment,
      ...settings,
      if (databaseUrl != null) 'DATABASE_URL': databaseUrl,
    },
  );
  process.stdout.transform(utf8.decoder).listen(
      (part) => stdout.write('[$app] $part'));
  process.stderr.transform(utf8.decoder).listen(
      (part) => stderr.write('[$app] $part'));
  await _ready(client, port);
  return process;
}

void main() {
  test('registration, email, login, recovery and NATS round trip', () async {
    final client = http.Client();
    final processes = <Process>[];
    const pg = 'postgresql://portal:local-dev-password@127.0.0.1:5433';
    final authDb = PostgresDatabase('$pg/auth_db?sslmode=disable');
    final registrationDb =
        PostgresDatabase('$pg/registration_db?sslmode=disable');
    final recoveryDb =
        PostgresDatabase('$pg/password_recovery_db?sslmode=disable');
    final emailDb = PostgresDatabase('$pg/email_db?sslmode=disable');
    final bus = NatsJetStreamEventBus('nats://127.0.0.1:4222');
    var connected = false;
    final email = 'integration-' +
        DateTime.now().microsecondsSinceEpoch.toString() + '@example.com';
    const previousPassword = 'Strong#Pass123';
    const nextPassword = 'New#Password456';
    final settings = <String, String>{
      'HTTP_HOST': '127.0.0.1',
      'PORTAL_INTERNAL_TOKEN': 'local-dev-token-change-me',
      'AUTH_SECRET': 'local-dev-auth-secret-change-me',
      'REGISTRATION_TOKEN_SECRET':
          'local-registration-token-secret-only-dev',
      'PASSWORD_RECOVERY_TOKEN_SECRET':
          'local-password-recovery-secret-only-dev-2026',
      'APP_URL': 'http://localhost:5173',
      'ALLOWED_ORIGINS': 'http://localhost:5173',
      'NATS_URL': 'nats://127.0.0.1:4222',
      'AUTH_SERVICE_URL': 'http://127.0.0.1:3001',
      'REGISTRATION_SERVICE_URL': 'http://127.0.0.1:3003',
      'PASSWORD_RECOVERY_SERVICE_URL': 'http://127.0.0.1:3009',
      'REGISTRATION_EVENTS_ENABLED': 'true',
      'PASSWORD_RECOVERY_EVENTS_ENABLED': 'true',
    };
    final gateway = Uri.parse('http://127.0.0.1:3100');

    Future<http.Response> post(String route, Map<String, dynamic> payload) =>
        client.post(gateway.resolve(route), headers: {
          'origin': 'http://localhost:5173',
          'content-type': 'application/json',
        }, body: jsonEncode(payload));

    try {
      for (final db in [authDb, registrationDb, recoveryDb, emailDb]) {
        expect(await db.ping(), true);
      }

      processes.add(await _launch('auth_service', 3001,
          '$pg/auth_db?sslmode=disable', settings, client));
      processes.add(await _launch('registration_service', 3003,
          '$pg/registration_db?sslmode=disable', settings, client));
      processes.add(await _launch('password_recovery_service', 3009,
          '$pg/password_recovery_db?sslmode=disable', settings, client));
      processes.add(await _launch('api_gateway', 3100, null, settings, client));

      await bus.connect();
      connected = true;
      final fakeGmail = _FakeGmail();
      await EmailEventHandler(
        bus: bus,
        inbox: PostgresEmailEvents(emailDb),
        delivery: fakeGmail,
        client: client,
        registrationUrl: Uri.parse('http://127.0.0.1:3003'),
        recoveryUrl: Uri.parse('http://127.0.0.1:3009'),
        internalToken: settings['PORTAL_INTERNAL_TOKEN']!,
      ).subscribe();

      final forbidden = await client.get(gateway.resolve(
          '/internal/auth/users/exists?email=' + email));
      expect(forbidden.statusCode, 404);

      final started = await post('/api/auth/register/request', {
        'email': email,
        'password': previousPassword,
        'confirmPassword': previousPassword,
        'terms': true,
      });
      expect(started.statusCode, 200, reason: started.body);
      final confirmation = await fakeGmail.confirmation.future
          .timeout(const Duration(seconds: 30));
      final code = confirmation.queryParameters['code']!;
      final pending = await registrationDb.query(
        'SELECT token_hash FROM email_verification_tokens WHERE email=@email',
        params: {'email': email},
      );
      expect(pending, hasLength(1));
      final regOutbox = await registrationDb.query(
        'SELECT payload FROM event_outbox WHERE type=@type',
        params: {'type': EmailEventHandler.verification},
      );
      expect(regOutbox, hasLength(1));
      expect(regOutbox.single['payload'].toString(), isNot(contains(code)));

      final verifyUrl = gateway.resolve('/api/auth/verify-email')
          .replace(queryParameters: {'code': code});
      final verified = await client.get(verifyUrl);
      expect(verified.statusCode, 200, reason: verified.body);
      final secondVerify = await client.get(verifyUrl);
      expect(secondVerify.statusCode, 400);

      final login = await post('/api/auth/login', {
        'email': email, 'password': previousPassword,
      });
      expect(login.statusCode, 200, reason: login.body);
      final matches = RegExp(r'portal_session=([^;,\s]+)')
          .allMatches(login.headers['set-cookie'] ?? '').toList();
      expect(matches, isNotEmpty);
      final cookie = 'portal_session=' + matches.last.group(1)!;
      final me = await client.get(gateway.resolve('/api/auth/me'),
          headers: {'origin': 'http://localhost:5173', 'cookie': cookie});
      expect(me.statusCode, 200, reason: me.body);
      expect(jsonDecode(me.body)['user']['email'], email);

      final unknown = await post('/api/auth/password/forgot', {
        'email': 'unknown-' + DateTime.now().microsecondsSinceEpoch.toString()
            + '@example.com',
      });
      final forgot = await post('/api/auth/password/forgot', {'email': email});
      expect(forgot.statusCode, 200);
      expect(forgot.body, unknown.body);
      final link = await fakeGmail.recovery.future
          .timeout(const Duration(seconds: 30));
      final resetCode = link.queryParameters['code']!;
      final recoveryOutbox = await recoveryDb.query(
        'SELECT payload FROM event_outbox WHERE type=@type',
        params: {'type': EmailEventHandler.recovery},
      );
      expect(recoveryOutbox, hasLength(1));
      expect(recoveryOutbox.single['payload'].toString(),
          isNot(contains(resetCode)));

      final resetRoute = '/api/auth/password/reset?code=' + resetCode;
      final payload = {
        'password': nextPassword, 'confirmPassword': nextPassword,
      };
      final reset = await post(resetRoute, payload);
      expect(reset.statusCode, 200, reason: reset.body);
      expect((await post(resetRoute, payload)).statusCode, 400);

      expect((await post('/api/auth/login', {
        'email': email, 'password': previousPassword,
      })).statusCode, 401);
      expect((await post('/api/auth/login', {
        'email': email, 'password': nextPassword,
      })).statusCode, 200);

      expect(fakeGmail.deliveries, containsAll(['verification', 'recovery']));
      final inbox = await emailDb.query(
          "SELECT type, status FROM event_inbox WHERE status='processed'");
      expect(inbox.map((row) => row['type']),
          containsAll([EmailEventHandler.verification, EmailEventHandler.recovery]));
    } finally {
      if (connected) await bus.close();
      for (final p in processes.reversed) {
        p.kill(ProcessSignal.sigterm);
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      for (final p in processes.reversed) {
        p.kill(ProcessSignal.sigkill);
      }
      client.close();
      for (final db in [authDb, registrationDb, recoveryDb, emailDb]) {
        await db.close();
      }
    }
  }, skip: Platform.environment['RUN_DART_INTEGRATION'] == 'true'
      ? null : 'Requires isolated PostgreSQL and NATS');
}
