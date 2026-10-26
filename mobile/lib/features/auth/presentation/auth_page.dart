import 'package:flutter/material.dart';
import '../../../core/theme/portal_theme.dart';
import '../auth_progress.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.title, required this.subtitle, required this.child});
  final String title, subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(
        colors: [PortalColors.background, PortalColors.wine, PortalColors.background],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      )),
      child: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: PortalColors.field,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: PortalColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Image.asset('assets/images/logo.png', width: 52, height: 52),
                const Spacer(),
                TextButton(onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                }, child: const Text('Voltar')),
              ]),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(fontFamily: 'serif', fontSize: 32,
                fontWeight: FontWeight.bold, color: PortalColors.goldLight)),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: PortalColors.muted, height: 1.5)),
              const SizedBox(height: 24),
              child,
              const AuthProgressBadge(),
            ]),
          ),
        ),
      ))),
    ),
  );
}

class AuthAction extends StatelessWidget {
  const AuthAction(this.label, {super.key, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 50,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: PortalColors.gold,
        foregroundColor: PortalColors.onGold),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}

class AuthNotice extends StatelessWidget {
  const AuthNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Text(message, style: const TextStyle(color: PortalColors.muted)),
  );
}
