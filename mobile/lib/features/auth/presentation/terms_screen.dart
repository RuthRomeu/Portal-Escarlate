import 'package:flutter/material.dart';
import '../../../core/theme/portal_theme.dart';
import 'auth_page.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const sections = <String, String>{
    'Dados tratados': 'Podemos tratar e-mail, dados de conta, histórico de pesquisas, datas de interação e registros necessários à segurança e operação.',
    'Finalidades': 'Os dados apoiam autenticação, histórico, métricas, melhorias do portal e comunicações relacionadas ao serviço, conforme as preferências aplicáveis.',
    'Consentimento e fundamento legal': 'O aceite registra a ciência dos termos. Outros fundamentos legais podem justificar tratamentos necessários à execução e proteção do serviço.',
    'Segurança e retenção': 'O acesso aos dados deve ser limitado às necessidades do portal; a retenção depende da finalidade, das obrigações legais e da segurança.',
    'Direitos do titular': 'Você pode solicitar acesso, correção e, quando aplicável, exclusão dos dados e revisão de suas preferências de comunicação.',
  };

  @override
  Widget build(BuildContext context) => AuthPage(
    title: 'Política de uso e privacidade',
    subtitle: 'Conheça as regras de acesso, tratamento de dados e seus direitos no Portal Escarlate.',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final entry in sections.entries) ...[
        Text(entry.key, style: const TextStyle(
          color: PortalColors.gold, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(entry.value, style: const TextStyle(
          color: PortalColors.muted, height: 1.5)),
        const SizedBox(height: 18),
      ],
    ]),
  );
}
