class AuthValidators {
  const AuthValidators._();

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Informe seu e-mail.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input)) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  static String? password(String? value) =>
      (value == null || value.isEmpty) ? 'Informe sua senha.' : null;

  static String? strongPassword(String? value) {
    final input = value ?? '';
    if (input.length < 8) return 'Ao menos 8 caracteres.';
    if (!RegExp(r'[A-Za-z]').hasMatch(input)) return 'Pelo menos uma letra.';
    if (!RegExp(r'[0-9]').hasMatch(input)) return 'Pelo menos um número.';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(input)) {
      return 'Pelo menos um caractere especial.';
    }
    return null;
  }

  static String? confirm(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirme a senha.';
    return value == password ? null : 'As senhas não conferem.';
  }
}
