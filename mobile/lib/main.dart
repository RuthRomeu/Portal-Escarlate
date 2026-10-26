import 'package:flutter/material.dart';

import 'core/theme/portal_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/terms_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';
import 'features/auth/presentation/verify_email_screen.dart';

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
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri == null) return null;
        if (uri.path == '/reset-password') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ResetPasswordScreen(code: uri.queryParameters['code']),
          );
        }
        if (uri.path == '/verify-email') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => VerifyEmailScreen(code: uri.queryParameters['code']),
          );
        }
        return null;
      },
    );
  }
}
