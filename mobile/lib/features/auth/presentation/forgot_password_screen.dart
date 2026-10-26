import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../auth_validators.dart';
import 'auth_page.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  String? _notice;

  void _submit() {
    if (_form.currentState!.validate()) {
      setState(() => _notice =
          'Demonstração: envio de e-mail ainda não integrado ao servidor.');
    }
  }

  @override
  Widget build(BuildContext context) => AuthPage(
    title: 'Esqueci minha senha',
    subtitle: 'Informe o e-mail cadastrado para solicitar um link de redefinição.',
    child: Form(key: _form, child: Column(children: [
      TextFormField(
        key: const Key('recovery-email'),
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        validator: AuthValidators.email,
        decoration: const InputDecoration(
          labelText: 'E-mail', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 18),
      AuthAction('Solicitar link de recuperação', onPressed: _submit),
      if (_notice != null) AuthNotice(_notice!),
      if (kDebugMode) TextButton(
        onPressed: () => Navigator.pushNamed(context, '/reset-password'),
        child: const Text('Prévia: redefinir senha'),
      ),
    ])),
  );
}
