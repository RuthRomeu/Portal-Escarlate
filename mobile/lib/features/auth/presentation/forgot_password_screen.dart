import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth_validators.dart';
import '../data/auth_api_client.dart';
import 'auth_page.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _api = AuthApiClient();

  bool _loading = false;
  String? _notice;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _notice = null;
    });

    // Chama POST /api/auth/password/forgot.
    // O backend retorna 200 mesmo se o e-mail não existir (por segurança,
    // não revela quais endereços estão cadastrados).
    final result = await _api.forgotPassword(_emailController.text);

    if (!mounted) return;
    setState(() {
      _loading = false;
      // Se ok, exibe mensagem genérica independente do resultado real.
      _notice = result.ok
          ? 'Se este e-mail estiver cadastrado, você receberá um link de recuperação em breve.'
          : result.message;
    });
  }

  @override
  Widget build(BuildContext context) => AuthPage(
    title: 'Esqueci minha senha',
    subtitle:
        'Informe o e-mail cadastrado para solicitar um link de redefinição.',
    child: Form(
      key: _form,
      child: Column(
        children: [
          TextFormField(
            key: const Key('recovery-email'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: AuthValidators.email,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          AuthAction(
            'Solicitar link de recuperação',
            onPressed: _loading ? null : _submit,
          ),
          if (_notice != null) AuthNotice(_notice!),
          if (kDebugMode)
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/reset-password'),
              child: const Text('Prévia: redefinir senha'),
            ),
        ],
      ),
    ),
  );
}
