class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    this.passwordHash,
  });

  final String id;
  final String email;
  final String role;
  final String? passwordHash;

  Map<String, String> toSessionJson() => {
        'id': id,
        'email': email,
        'role': role,
      };
}

String normalizeEmail(String email) => email.trim().toLowerCase();

String? validateEmail(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return 'Informe um e-mail válido.';
  }
  final email = normalizeEmail(value);
  if (email.length > 254 ||
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'Informe um e-mail válido.';
  }
  return null;
}

String? validateNewPassword(Object? value) {
  if (value is! String || value.length < 8) {
    return 'Ao menos 8 caracteres.';
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
    return 'Pelo menos uma letra.';
  }
  if (!RegExp(r'[0-9]').hasMatch(value)) {
    return 'Pelo menos um número.';
  }
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
    return 'Pelo menos um caractere especial.';
  }
  return null;
}
