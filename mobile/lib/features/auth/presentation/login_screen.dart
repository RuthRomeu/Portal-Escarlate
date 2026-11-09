import 'package:flutter/material.dart';

import '../../../core/theme/portal_theme.dart';
import '../auth_progress.dart';
import '../data/auth_api_client.dart';
import '../../news/presentation/news_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = AuthApiClient();

  bool _obscurePassword = true;
  bool _loading = false;

  String _message =
      'Informe suas credenciais para acessar sua área de pesquisa.';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _message = 'Autenticando…';
    });

    // Chama POST /api/auth/login no gateway (porta 3000).
    // O AuthApiClient envia { email, password } e salva o cookie
    // portal_session que o backend retorna no Set-Cookie.
    final result = await _api.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (result.ok) {
      // Login bem-sucedido: navega para a tela de notícias.
      // pushReplacement impede que o usuário volte para o login
      // com o botão físico "voltar".
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => NewsScreen(apiClient: _api)),
      );
      return;
    }

    setState(() {
      _loading = false;
      _message = result.message ?? 'Não foi possível autenticar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PortalColors.background,
              PortalColors.wine,
              PortalColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.all(isWide ? 24 : 0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (isWide ? 48 : 0),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(isWide ? 28 : 0),
                          border: isWide
                              ? Border.all(color: PortalColors.border)
                              : null,
                          color: const Color(0xAA140607),
                        ),
                        child: isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 11, child: _buildHero(true)),
                                  Expanded(flex: 9, child: _buildPortal(true)),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildHero(false),
                                  _buildPortal(false),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHero(bool wide) {
    return Container(
      padding: EdgeInsets.all(wide ? 48 : 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: wide
              ? BorderSide.none
              : const BorderSide(color: PortalColors.border),
          right: wide
              ? const BorderSide(color: PortalColors.border)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: wide ? 90 : 68,
            height: wide ? 90 : 68,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 18),
          const Text(
            'PESQUISA INTELIGENTE E ANÁLISE ASSISTIDA',
            style: TextStyle(
              fontSize: 10,
              color: PortalColors.muted,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Portal',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: wide ? 64 : 44,
              height: 1,
              color: PortalColors.goldLight,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Escarlate',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: wide ? 64 : 44,
              height: 1.1,
              color: PortalColors.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Encontre notícias relevantes, compare fontes '
            'e transforme resultados dispersos em uma '
            'leitura clara com apoio de inteligência artificial.',
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: PortalColors.muted,
            ),
          ),
          SizedBox(height: wide ? 44 : 20),
          _buildRadar(),
          if (wide) ...[
            const SizedBox(height: 32),
            const Text(
              'TEMAS  •  RESUMOS  •  FONTES',
              style: TextStyle(
                color: PortalColors.gold,
                letterSpacing: 2,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRadar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PortalColors.border),
        color: const Color(0xAA080304),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RADAR EDITORIAL',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.3,
                  color: PortalColors.muted,
                ),
              ),
              Text(
                'AO VIVO',
                style: TextStyle(
                  fontSize: 11,
                  color: PortalColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          for (final fraction in [0.95, 0.78, 0.62]) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        PortalColors.wine,
                        PortalColors.gold,
                        PortalColors.ruby,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _topic('Política'),
              _topic('Economia'),
              _topic('Ciência'),
              _topic('Cultura'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topic(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: PortalColors.border),
        color: PortalColors.darkWine,
      ),
      child: Text(
        label,
        style: const TextStyle(color: PortalColors.muted, fontSize: 12),
      ),
    );
  }

  Widget _buildPortal(bool wide) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 38 : 20,
        vertical: wide ? 64 : 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ACESSO EDITORIAL RESTRITO',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: PortalColors.muted,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Acesse o portal',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: PortalColors.goldLight,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Entre para explorar temas relevantes com '
                'pesquisa inteligente e acompanhar sínteses '
                'claras a partir dos resultados encontrados.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: PortalColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              _buildModeSwitch(),
              const SizedBox(height: 22),
              _buildForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitch() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: PortalColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PortalColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.center,
              height: 44,
              decoration: BoxDecoration(
                color: PortalColors.darkWine,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PortalColors.goldDark),
              ),
              child: const Text(
                'LOGIN',
                style: TextStyle(
                  color: PortalColors.goldLight,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text(
                'CADASTRO',
                style: TextStyle(color: PortalColors.muted, letterSpacing: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: PortalColors.muted, fontSize: 14),
      filled: true,
      fillColor: PortalColors.field,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PortalColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PortalColors.gold, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PortalColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PortalColors.danger, width: 1.4),
      ),
    );
  }

  Widget _label(String value) {
    return Text(
      value,
      style: const TextStyle(
        color: PortalColors.muted,
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('E-MAIL'),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('email-field'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            autocorrect: false,
            decoration: _inputDecoration('usuario@exemplo.com.br'),
            validator: (value) {
              final email = value?.trim() ?? '';

              if (email.isEmpty) {
                return 'Informe seu e-mail.';
              }

              final validEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

              if (!validEmail.hasMatch(email)) {
                return 'Informe um e-mail válido.';
              }

              return null;
            },
          ),
          const SizedBox(height: 18),
          _label('SENHA'),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('password-field'),
            controller: _passwordController,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            decoration: _inputDecoration(
              'Digite sua senha',
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: PortalColors.muted,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Informe sua senha.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/forgot-password'),
                child: const Text('Esqueci minha senha'),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/terms'),
                child: const Text('Termos de uso'),
              ),
            ],
          ),
          const Text(
            'Ao entrar, você concorda com as políticas '
            'de coleta e uso de dados.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: PortalColors.muted,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const LinearGradient(
                  colors: [
                    PortalColors.goldLight,
                    PortalColors.gold,
                    PortalColors.goldDark,
                  ],
                ),
              ),
              child: ElevatedButton(
                key: const Key('enter-button'),
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: PortalColors.onGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PortalColors.onGold,
                        ),
                      )
                    : const Text(
                        'ENTRAR NO PORTAL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.3,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'NOTÍCIAS DE ALTO IMPACTO • CONSULTA RESERVADA',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PortalColors.muted,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PortalColors.border),
              color: PortalColors.background,
            ),
            child: Text(
              _message,
              style: const TextStyle(
                color: PortalColors.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const AuthProgressBadge(),
        ],
      ),
    );
  }
}
