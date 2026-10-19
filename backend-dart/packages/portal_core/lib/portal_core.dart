import 'dart:io';

class ServiceConfig {
  const ServiceConfig({required this.name, required this.defaultPort});

  final String name;
  final int defaultPort;

  String get host => Platform.environment['HTTP_HOST'] ?? '0.0.0.0';
  int get port => int.tryParse(Platform.environment['HTTP_PORT'] ?? '') ?? defaultPort;
  String? get databaseUrl => Platform.environment['DATABASE_URL'];
  String? get internalToken => Platform.environment['PORTAL_INTERNAL_TOKEN'];
  String get natsUrl => Platform.environment['NATS_URL'] ?? 'nats://127.0.0.1:4222';
  bool get demoEnabled => Platform.environment['ENABLE_DEMO_EVENTS'] == 'true';
}

/// Compara bytes sem interromper no primeiro caractere diferente.
bool safeTokenEquals(String? provided, String? expected) {
  if (provided == null || expected == null || expected.isEmpty) return false;
  var difference = provided.length ^ expected.length;
  for (var i = 0; i < expected.length; i++) {
    final actual = i < provided.length ? provided.codeUnitAt(i) : 0;
    difference |= actual ^ expected.codeUnitAt(i);
  }
  return difference == 0;
}
