import 'dart:convert';
import 'dart:io';

import 'package:portal_core/portal_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

Response jsonReply(int status, Object value) => Response(status,
  body: jsonEncode(value),
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

/// Utilizado somente por microsserviços: autenticação entre Gateway e serviços.
Middleware internalAccess(String? token) => (inner) => (request) {
  if (request.url.path == 'health/live') return inner(request);
  if (!safeTokenEquals(request.headers['x-internal-token'], token)) {
    return jsonReply(403, {'error': 'forbidden'});
  }
  return inner(request);
};

typedef RoutesBuilder = void Function(Router router, ServiceConfig config);

Future<HttpServer> runService({
  required String name,
  required int port,
  RoutesBuilder? registerRoutes,
}) async {
  final config = ServiceConfig(name: name, defaultPort: port);
  final routes = Router()
    ..get('/health/live', (Request request) => jsonReply(200,
        {'status': 'ok', 'service': config.name}));
  registerRoutes?.call(routes, config);
  final handler = const Pipeline()
      .addMiddleware(internalAccess(config.internalToken))
      .addHandler(routes.call);
  final server = await shelf_io.serve(handler, config.host, config.port);
  stdout.writeln('[${config.name}] listening on ${server.address.address}:${server.port}');
  ProcessSignal.sigterm.watch().listen((_) => server.close(force: true));
  ProcessSignal.sigint.watch().listen((_) => server.close(force: true));
  return server;
}
