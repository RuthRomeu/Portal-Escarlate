import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_escarlate_app/main.dart';

void main() {
  testWidgets('Recuperação acessível pelo login e validada localmente', (tester) async {
    await tester.pumpWidget(const PortalEscarlateApp());
    final link = find.text('Esqueci minha senha');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recovery-email')), findsOneWidget);
    expect(find.textContaining('AUTENTICAÇÃO '), findsOneWidget);
  });
}
