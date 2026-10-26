import 'package:flutter/material.dart';

import 'core/theme/portal_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/terms_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PortalEscarlateApp());
}

class PortalEscarlateApp extends StatelessWidget {
  const PortalEscarlateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portal Escarlate',
      debugShowCheckedModeBanner: false,
      theme: PortalTheme.dark,
      home: const LoginScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/terms': (_) => const TermsScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
      },
    );
  }
}
