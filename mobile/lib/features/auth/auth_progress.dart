import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/portal_theme.dart';

class AuthProgressBadge extends StatelessWidget {
  const AuthProgressBadge({super.key});
  static const completed = 1;
  static const total = 6;

  @override
  Widget build(BuildContext context) => kDebugMode
      ? Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(child: Text(
            'AUTENTICAÇÃO $completed/$total • FALTAM ${total - completed}',
            key: const Key('auth-progress'),
            style: const TextStyle(color: PortalColors.goldDark, fontSize: 10),
          )),
        )
      : const SizedBox.shrink();
}
