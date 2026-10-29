class EmailConnection {
  const EmailConnection({
    required this.id,
    required this.provider,
    required this.email,
    required this.refreshToken,
    required this.active,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String provider;
  final String email;
  final String refreshToken;
  final bool active;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> publicJson({Map<String, String>? health}) => {
    'id': id, 'provider': provider, 'email': email,
    'active': active, 'priority': priority,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (health != null) 'health': health,
  };
}

abstract interface class EmailConnectionRepository {
  Future<List<EmailConnection>> list();
  Future<EmailConnection?> active();
  Future<EmailConnection> save(String email, String refreshToken, {int priority = 100});
  Future<EmailConnection?> changePriority(String id, int priority);
  Future<bool> delete(String id);
}

enum EventClaim { claimed, processed, busy }

abstract interface class EmailEventRepository {
  Future<EventClaim> claim(String eventId, String eventType);
  Future<void> complete(String eventId, String eventType, String requestId);
  Future<void> release(String eventId);
}
