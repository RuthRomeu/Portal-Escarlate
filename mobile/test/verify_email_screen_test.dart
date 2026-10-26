import 'package:flutter_test/flutter_test.dart';
import 'package:portal_escarlate_app/main.dart';

void main() {
  testWidgets('Verificação acessível como prévia pelo cadastro', (tester) async {
    await tester.pumpWidget(const PortalEscarlateApp());
    final register = find.text('CADASTRO');
    await tester.ensureVisible(register);
    await tester.tap(register);
    await tester.pumpAndSettle();
    final preview = find.text('Prévia: verificar e-mail');
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(find.text('Verificação de e-mail'), findsOneWidget);
    expect(find.textContaining('AUTENTICAÇÃO '), findsOneWidget);
  });
}
