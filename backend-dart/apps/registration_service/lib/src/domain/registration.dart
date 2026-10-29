class PendingRegistration {
  const PendingRegistration({
    required this.id,
    required this.email,
    required this.passwordHash,
    required this.expiresAt,
    this.consumedAt,
  });

  final String id;
  final String email;
  final String passwordHash;
  final DateTime expiresAt;
  final DateTime? consumedAt;

  bool isValidAt(DateTime now) =>
      consumedAt == null && expiresAt.isAfter(now.toUtc());
}

String normalizeRegistrationEmail(String value) => value.trim().toLowerCase();

abstract interface class RegistrationRepository {
  Future<PendingRegistration> request({
    required String requestId,
    required String email,
    required String passwordHash,
    required String tokenHash,
    required DateTime expiresAt,
  });

  Future<PendingRegistration?> findRequest(String requestId);

  Future<bool> verify(
    String tokenHash,
    Future<void> Function(PendingRegistration) create,
  );
}

abstract interface class AuthRegistrationClient {
  Future<bool> userExists(String email);
  Future<void> createUser(PendingRegistration registration);
}

class RegistrationException implements Exception {
  const RegistrationException(this.status, this.message);
  final int status;
  final String message;
}

Map<String, List<String>> registrationErrors(Map<String, dynamic> data) {
  final errors = <String, List<String>>{};
  final email = data['email'];
  if (email is! String ||
      email.trim().length > 254 ||
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
          .hasMatch(email.trim())) {
    errors['email'] = ['Informe um e-mail válido.'];
  }
  final password = data['password'];
  if (password is! String || password.length < 8) {
    errors['password'] = ['Ao menos 8 caracteres.'];
  } else if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
    errors['password'] = ['Pelo menos uma letra.'];
  } else if (!RegExp(r'[0-9]').hasMatch(password)) {
    errors['password'] = ['Pelo menos um número.'];
  } else if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
    errors['password'] = ['Pelo menos um caractere especial.'];
  }
  final confirm = data['confirmPassword'];
  if (confirm is! String || confirm.isEmpty) {
    errors['confirmPassword'] = ['Confirme a senha.'];
  } else if (confirm != password) {
    errors['confirmPassword'] = ['A confirmação de senha não confere.'];
  }
  if (data['terms'] != true) {
    errors['terms'] = ['É preciso aceitar os termos de acesso.'];
  }
  return errors;
}
