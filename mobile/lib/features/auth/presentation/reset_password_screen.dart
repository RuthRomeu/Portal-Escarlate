import 'package:flutter/material.dart';
import '../auth_validators.dart';
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
  String? _notice;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      setState(() => _notice =
          'Demonstração: alteração de senha ainda não integrada ao servidor.');
    }
  }

  @override
  Widget build(BuildContext context) => AuthPage(
    title: 'Definir nova senha',
    subtitle: 'Escolha uma senha forte para recuperar o acesso à sua conta.',
    child: Form(key: _form, child: Column(children: [
      if (widget.code?.isNotEmpty != true)
        const AuthNotice('Nenhum código de recuperação informado. Interface de demonstração.'),
      AuthPasswordField(label: 'Nova senha', controller: _password,
        validator: AuthValidators.strongPassword),
      const SizedBox(height: 14),
      AuthPasswordField(label: 'Confirmar nova senha', controller: _confirmation,
        validator: (value) => AuthValidators.confirm(value, _password.text)),
      const SizedBox(height: 20),
      AuthAction('Redefinir senha', onPressed: _submit),
      if (_notice != null) AuthNotice(_notice!),
    ])),
  );
}
