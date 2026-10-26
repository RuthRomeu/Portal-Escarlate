import 'package:flutter/material.dart';
import 'auth_page.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key, this.code});
  final String? code;

  @override
  Widget build(BuildContext context) {
    final hasCode = code?.trim().isNotEmpty == true;
    return AuthPage(
      title: 'Verificação de e-mail',
      subtitle: 'Confirme o endereço de e-mail utilizado no cadastro.',
      child: Column(children: [
        Icon(hasCode ? Icons.mark_email_unread_outlined : Icons.mail_outline,
          color: Theme.of(context).colorScheme.primary, size: 48),
        const SizedBox(height: 16),
        AuthNotice(hasCode
          ? 'Código recebido. A validação no servidor ainda não está integrada.'
          : 'Nenhum código informado. Esta é uma prévia; o link real será enviado por e-mail.'),
        const SizedBox(height: 20),
        AuthAction('Voltar para o login',
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context, '/login', (_) => false)),
      ]),
    );
  }
}
