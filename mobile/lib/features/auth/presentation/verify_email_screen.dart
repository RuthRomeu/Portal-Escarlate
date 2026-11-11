import 'package:flutter/material.dart';

import '../../../core/theme/portal_theme.dart';
import '../data/auth_api_client.dart';
import 'auth_page.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.code});
  final String? code;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _api = AuthApiClient();

  bool _loading = false;
  bool? _success; // null = não tentou, true = verificado, false = falhou
  String? _message;

  @override
  void initState() {
    super.initState();
    final code = widget.code;
    if (code != null && code.trim().isNotEmpty) {
      _verify(code.trim());
    }
  }

  Future<void> _verify(String code) async {
    setState(() {
      _loading = true;
      _message = null;
    });

    // Chama GET /api/auth/verify-email?code=...
    // O Registration Service valida o token e confirma o cadastro.
    final result = await _api.verifyEmail(code);

    if (!mounted) return;

    setState(() {
      _loading = false;
      _success = result.ok;
      _message = result.ok
          ? (result.data?['message'] as String?) ??
                'E-mail verificado com sucesso. Agora você pode fazer login.'
          : result.message ?? 'Não foi possível verificar o e-mail.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasCode = widget.code?.trim().isNotEmpty == true;

    final IconData icon;
    final Color iconColor;
    if (_loading) {
      icon = Icons.hourglass_top_outlined;
      iconColor = PortalColors.gold;
    } else if (_success == true) {
      icon = Icons.mark_email_read_outlined;
      iconColor = PortalColors.gold;
    } else if (_success == false) {
      icon = Icons.error_outline;
      iconColor = PortalColors.danger;
    } else {
      icon = hasCode ? Icons.mark_email_unread_outlined : Icons.mail_outline;
      iconColor = PortalColors.muted;
    }

    final String notice;
    if (_loading) {
      notice = 'Verificando seu e-mail no servidor…';
    } else if (_message != null) {
      notice = _message!;
    } else if (hasCode) {
      notice = 'Aguardando verificação…';
    } else {
      notice = 'Nenhum código informado. O link de verificação será enviado por e-mail após o cadastro.';
    }

    return AuthPage(
      title: 'Verificação de e-mail',
      subtitle: 'Confirme o endereço de e-mail utilizado no cadastro.',
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 48),
          const SizedBox(height: 16),
          AuthNotice(notice),
          const SizedBox(height: 20),
          AuthAction(
            'Voltar para o login',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (_) => false,
            ),
          ),
        ],
      ),
    );
  }
}
