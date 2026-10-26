import 'package:flutter/material.dart';
import '../auth_validators.dart';
import 'auth_page.dart';
import 'auth_password_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _accepted = false;
  String? _notice;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    final valid = _form.currentState!.validate();
    setState(() => _notice = !_accepted
        ? 'Aceite os termos para prosseguir.'
        : valid ? 'Demonstração: cadastro ainda não integrado ao servidor.' : null);
  }

  @override
  Widget build(BuildContext context) => AuthPage(
    title: 'Criar sua conta',
    subtitle: 'Cadastre seu e-mail e escolha uma senha segura para acessar o portal.',
    child: Form(key: _form, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        key: const Key('register-email'),
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        validator: AuthValidators.email,
        decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 14),
      AuthPasswordField(label: 'Senha', controller: _password,
        validator: AuthValidators.strongPassword),
      const SizedBox(height: 14),
      AuthPasswordField(label: 'Confirmar senha', controller: _confirmation,
        validator: (value) => AuthValidators.confirm(value, _password.text)),
      const SizedBox(height: 8),
      CheckboxListTile(
        key: const Key('register-terms'), contentPadding: EdgeInsets.zero,
        title: const Text('Aceito os termos de acesso e coleta de dados',
          style: TextStyle(fontSize: 13)),
        value: _accepted,
        onChanged: (value) => setState(() => _accepted = value ?? false),
      ),
      Align(alignment: Alignment.centerLeft,
        child: TextButton(onPressed: () => Navigator.pushNamed(context, '/terms'),
          child: const Text('Ler os termos de uso'))),
      const SizedBox(height: 12),
      AuthAction('Criar acesso', onPressed: _submit),
      if (_notice != null) AuthNotice(_notice!),
    ])),
  );
}
