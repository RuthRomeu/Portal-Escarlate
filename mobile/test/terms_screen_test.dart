import 'package:flutter_test/flutter_test.dart';
import 'package:portal_escarlate_app/main.dart';

void main() {
  testWidgets('Termos disponíveis e etapa contabilizada', (tester) async {
    await tester.pumpWidget(const PortalEscarlateApp());
    final link = find.text('Termos de uso');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Política de uso e privacidade'), findsOneWidget);
    expect(find.textContaining('AUTENTICAÇÃO '), findsOneWidget);
  });
}
