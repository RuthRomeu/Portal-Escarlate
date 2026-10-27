import 'dart:math';

class EventEnvelope {
  const EventEnvelope({
    required this.eventId,
    required this.type,
    required this.schemaVersion,
    required this.source,
    required this.occurredAt,
    required this.payload,
    this.correlationId,
  });

  final String eventId;
  final String type;
  final int schemaVersion;
  final String source;
  final DateTime occurredAt;
  final String? correlationId;
  final Map<String, dynamic> payload;

  factory EventEnvelope.create({
    required String type,
    required String source,
    required Map<String, dynamic> payload,
    String? correlationId,
  }) => EventEnvelope(
    eventId: newEventId(),
    type: type,
    schemaVersion: 1,
    source: source,
    occurredAt: DateTime.now().toUtc(),
    payload: payload,
    correlationId: correlationId,
  );

  factory EventEnvelope.fromJson(Map<String, dynamic> json) => EventEnvelope(
    eventId: json['eventId'] as String,
    type: json['type'] as String,
    schemaVersion: json['schemaVersion'] as int,
    source: json['source'] as String,
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    correlationId: json['correlationId'] as String?,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
  );

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'type': type,
    'schemaVersion': schemaVersion,
    'source': source,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    if (correlationId != null) 'correlationId': correlationId,
    'payload': payload,
  };
}

String newEventId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}


/// Contratos iniciais do barramento NATS (somente eventos assíncronos).
/// Tokens e links secretos jamais devem ser persistidos nos payloads.
abstract final class PortalEventTypes {
  static const verificationRequested = 'portal.registration.verification_requested.v1';
  static const emailVerified = 'portal.registration.email_verified.v1';
  static const passwordRecoveryRequested = 'portal.password_recovery.requested.v1';
  static const loginSucceeded = 'portal.auth.login_succeeded.v1';
  static const passwordReset = 'portal.auth.password_reset.v1';
  static const deliverySucceeded = 'portal.email.delivery_succeeded.v1';
  static const deliveryFailed = 'portal.email.delivery_failed.v1';
}
