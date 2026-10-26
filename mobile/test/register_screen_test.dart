import 'package:flutter_test/flutter_test.dart';
import 'package:portal_escarlate_app/main.dart';

void main() {
  testWidgets('Cadastro acessível pelo login e contabilizado', (tester) async {
    await tester.pumpWidget(const PortalEscarlateApp());
    final button = find.text('CADASTRO');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Criar sua conta'), findsOneWidget);
    expect(find.textContaining('AUTENTICAÇÃO '), findsOneWidget);
  });
}
