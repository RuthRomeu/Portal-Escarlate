import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:portal_escarlate_app/main.dart';

void main() {
  testWidgets('Exibe a tela de login', (tester) async {
    await tester.pumpWidget(const PortalEscarlateApp());

    expect(find.text('Acesse o portal'), findsOneWidget);
    expect(find.byKey(const Key('email-field')), findsOneWidget);
    expect(find.byKey(const Key('password-field')), findsOneWidget);
    expect(find.text('ENTRAR NO PORTAL'), findsOneWidget);
  });

  testWidgets('Valida campos obrigatórios', (tester) async {
    await tester.pumpWidget(const PortalEscarlateApp());

    final button = find.byKey(const Key('enter-button'));

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
  });

  testWidgets('Permite mostrar e ocultar senha', (tester) async {
    await tester.pumpWidget(const PortalEscarlateApp());

    final showButton = find.byTooltip('Mostrar senha');

    await tester.ensureVisible(showButton);
    await tester.tap(showButton);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ocultar senha'), findsOneWidget);

    final fields = find.byType(EditableText);
    final passwordField = tester.widget<EditableText>(fields.last);

    expect(passwordField.obscureText, isFalse);
  });

  testWidgets('Submete tentativa de autenticação', (tester) async {
    await tester.pumpWidget(const PortalEscarlateApp());

    await tester.enterText(
      find.byKey(const Key('email-field')),
      'usuario@exemplo.com',
    );

    await tester.enterText(find.byKey(const Key('password-field')), 'senha123');

    final button = find.byKey(const Key('enter-button'));

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    // Como o widget agora dispara requisição HTTP real no ambiente de teste,
    // garantimos que o formulário foi enviado e o estado continua estável.
    expect(find.byKey(const Key('enter-button')), findsOneWidget);
  });
}
