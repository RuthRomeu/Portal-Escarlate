class PendingRecovery {
  const PendingRecovery({
    required this.id,
    required this.email,
    required this.expiresAt,
    this.consumedAt,
  });

  final String id;
  final String email;
  final DateTime expiresAt;
  final DateTime? consumedAt;

  bool isValidAt(DateTime now) =>
      consumedAt == null && expiresAt.isAfter(now.toUtc());
}

abstract interface class RecoveryRepository {
  Future<PendingRecovery> request({
    required String requestId,
    required String email,
    required String tokenHash,
    required DateTime expiresAt,
  });

  Future<PendingRecovery?> findRequest(String requestId);

  /// Serialize uses of the same token; commit consumption only after Auth
  /// confirms the password change.
  Future<bool> reset(
    String tokenHash,
    Future<void> Function(PendingRecovery) changePassword,
  );
}

abstract interface class RecoveryAuthClient {
  Future<bool> userExists(String email);
  Future<void> changePassword(PendingRecovery pending, String password);
}

class RecoveryException implements Exception {
  const RecoveryException(this.status, this.message);
  final int status;
  final String message;
}

String normalizeRecoveryEmail(String email) => email.trim().toLowerCase();

Map<String, List<String>> forgotErrors(Map<String, dynamic> input) {
  final email = input['email'];
  if (email is! String ||
      email.trim().length > 254 ||
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
    return {'email': ['Informe um e-mail válido.']};
  }
  return {};
}

Map<String, List<String>> resetErrors(Map<String, dynamic> input) {
  final errors = <String, List<String>>{};
  final password = input['password'];
  if (password is! String || password.length < 8) {
    errors['password'] = ['Ao menos 8 caracteres.'];
  } else if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
    errors['password'] = ['Pelo menos uma letra.'];
  } else if (!RegExp(r'[0-9]').hasMatch(password)) {
    errors['password'] = ['Pelo menos um número.'];
  } else if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
    errors['password'] = ['Pelo menos um caractere especial.'];
  }
  final confirmation = input['confirmPassword'];
  if (confirmation is! String || confirmation.isEmpty) {
    errors['confirmPassword'] = ['Confirme a senha.'];
  } else if (confirmation != password) {
    errors['confirmPassword'] = ['A confirmação de senha não confere.'];
  }
  return errors;
}
