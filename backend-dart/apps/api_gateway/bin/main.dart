import 'dart:async';
import 'dart:io';

import 'package:api_gateway/api_gateway.dart';
import 'package:portal_core/portal_core.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

const services = <String, int>{
  'auth': 3001,
  'news': 3002,
  'registration': 3003,
  'ai': 3004,
  'email': 3005,
  'news-summary': 3006,
  'article-summary': 3008,
  'password-recovery': 3009,
};

Future<void> main() async {
  final config = ServiceConfig(name: 'api-gateway', defaultPort: 3100);
  final targets = <String, Uri>{};
  for (final service in services.entries) {
    final key = service.key.toUpperCase().replaceAll('-', '_');
    final url = Platform.environment[key + '_SERVICE_URL'];
    targets[service.key] = Uri.parse(
        url ?? 'http://127.0.0.1:' + service.value.toString());
  }

  // Features not migrated to Dart keep running in the Node backend.
  // An absent legacy URL must NOT accidentally route traffic to Dart stubs.
  const legacyServices = ['news', 'ai', 'news-summary', 'article-summary'];
  final legacyValue = Platform.environment['LEGACY_BACKEND_URL']?.trim();
  if (legacyValue == null || legacyValue.isEmpty) {
    for (final name in legacyServices) {
      targets.remove(name);
    }
  } else {
    final legacy = Uri.parse(legacyValue);
    if (!(legacy.scheme == 'http' || legacy.scheme == 'https') ||
        legacy.host.isEmpty || legacy.userInfo.isNotEmpty ||
        legacy.pathSegments.where((segment) => segment.isNotEmpty).isNotEmpty ||
        legacy.hasQuery || legacy.hasFragment) {
      throw FormatException('LEGACY_BACKEND_URL deve ser uma origem HTTP(S).');
    }
    for (final name in legacyServices) {
      targets[name] = legacy;
    }
  }

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  final handler = buildGatewayHandler(
    targets: targets,
    internalToken: config.internalToken,
    origins: gatewayOrigins(Platform.environment),
    client: client,
  );
  final server = await shelf_io.serve(
    handler,
    config.host,
    config.port,
  );
  stdout.writeln('[gateway] listening on ' +
      server.address.address + ':' + server.port.toString());

  Future<void> shutdown() async {
    await server.close(force: true);
    client.close(force: true);
  }
  ProcessSignal.sigterm.watch().listen((_) => unawaited(shutdown()));
  ProcessSignal.sigint.watch().listen((_) => unawaited(shutdown()));
}
