import 'package:shelf/shelf.dart';

/// NUNCA permitir hostname escolhido pelo cliente (evita SSRF).
Uri? resolveUpstream(Request request, Map<String, Uri> targets) {
  final segments = request.url.pathSegments;
  if (segments.length < 3 || segments[0] != 'api') return null;
  final base = targets[segments[1]];
  if (base == null) return null;
  final suffix = segments.skip(2).join('/');
  return base.replace(path: '/$suffix', query: request.url.query.isEmpty ? null : request.url.query);
}

