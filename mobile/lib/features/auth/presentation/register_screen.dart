import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth_validators.dart';
import '../data/auth_api_client.dart';
import 'auth_page.dart';
import 'auth_password_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _api = AuthApiClient();

  bool _accepted = false;
  bool _loading = false;
  String? _notice;

  @override
  void dispose() {
    _emailController.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    if (!_accepted) {
      setState(() => _notice = 'Aceite os termos para prosseguir.');
      return;
    }
    if (!valid) return;

    setState(() {
      _loading = true;
      _notice = null;
    });

    // Chama POST /api/auth/register.
    // O Registration Service valida o e-mail, cria o token e envia o
    // link de verificação. A conta só existe no banco após o clique no link.
    final result = await _api.register(_emailController.text, _password.text);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _notice = result.ok
          ? 'Verifique seu e-mail para confirmar o cadastro.'
          : result.message;
    });
  }

  @override
  Widget build(BuildContext context) => AuthPage(
    title: 'Criar sua conta',
    subtitle:
        'Cadastre seu e-mail e escolha uma senha segura para acessar o portal.',
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            key: const Key('register-email'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: AuthValidators.email,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          AuthPasswordField(
            label: 'Senha',
            controller: _password,
            validator: AuthValidators.strongPassword,
          ),
          const SizedBox(height: 14),
          AuthPasswordField(
            label: 'Confirmar senha',
            controller: _confirmation,
            validator: (value) => AuthValidators.confirm(value, _password.text),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const Key('register-terms'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Aceito os termos de acesso e coleta de dados',
              style: TextStyle(fontSize: 13),
            ),
            value: _accepted,
            onChanged: (value) => setState(() => _accepted = value ?? false),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/terms'),
              child: const Text('Ler os termos de uso'),
            ),
          ),
          const SizedBox(height: 12),
          AuthAction('Criar acesso', onPressed: _loading ? null : _submit),
          if (_notice != null) AuthNotice(_notice!),
          if (kDebugMode)
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/verify-email'),
              child: const Text('Prévia: verificar e-mail'),
            ),
        ],
      ),
    ),
  );
}
