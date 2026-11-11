import 'package:flutter/material.dart';

import '../auth_validators.dart';
import '../data/auth_api_client.dart';
import 'auth_page.dart';
import 'auth_password_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.code});
  final String? code;
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _api = AuthApiClient();

  bool _loading = false;
  String? _notice;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    final code = widget.code;
    if (code == null || code.trim().isEmpty) {
      setState(() => _notice = 'Nenhum código de recuperação informado.');
      return;
    }

    setState(() {
      _loading = true;
      _notice = null;
    });

    // Chama POST /api/auth/password/reset?code=... com a nova senha no corpo.
    final result = await _api.resetPassword(code, _password.text);

    if (!mounted) return;

    if (result.ok) {
      setState(() {
        _loading = false;
        _notice = 'Senha redefinida com sucesso. Faça login com a nova senha.';
      });
      // Dá um instante para o usuário ler a mensagem e volta para o login.
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      });
      return;
    }

    setState(() {
      _loading = false;
      _notice = result.message ?? 'Não foi possível redefinir a senha.';
    });
  }

  @override
  Widget build(BuildContext context) => AuthPage(
    title: 'Definir nova senha',
    subtitle: 'Escolha uma senha forte para recuperar o acesso à sua conta.',
    child: Form(
      key: _form,
      child: Column(
        children: [
          if (widget.code?.isNotEmpty != true)
            const AuthNotice(
              'Nenhum código de recuperação informado. Verifique o link recebido por e-mail.',
            ),
          AuthPasswordField(
            label: 'Nova senha',
            controller: _password,
            validator: AuthValidators.strongPassword,
          ),
          const SizedBox(height: 14),
          AuthPasswordField(
            label: 'Confirmar nova senha',
            controller: _confirmation,
            validator: (value) => AuthValidators.confirm(value, _password.text),
          ),
          const SizedBox(height: 20),
          AuthAction('Redefinir senha', onPressed: _loading ? null : _submit),
          if (_notice != null) AuthNotice(_notice!),
        ],
      ),
    ),
  );
}
