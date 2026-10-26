import 'package:flutter_test/flutter_test.dart';
import 'package:portal_escarlate_app/main.dart';

void main() {
  testWidgets('Abre a prévia de redefinição pela recuperação', (tester) async {
    await tester.pumpWidget(const PortalEscarlateApp());
    final link = find.text('Esqueci minha senha');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    final preview = find.text('Prévia: redefinir senha');
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(find.text('Definir nova senha'), findsOneWidget);
    expect(find.textContaining('AUTENTICAÇÃO '), findsOneWidget);
  });
}
