import 'package:flutter/material.dart';

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({super.key, required this.label,
    required this.controller, required this.validator});
  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _hidden,
    validator: widget.validator,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(
      labelText: widget.label, border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        tooltip: _hidden ? 'Mostrar senha' : 'Ocultar senha',
        onPressed: () => setState(() => _hidden = !_hidden),
        icon: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      ),
    ),
  );
}
