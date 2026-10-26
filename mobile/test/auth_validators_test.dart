import 'package:flutter_test/flutter_test.dart';
import 'package:portal_escarlate_app/features/auth/auth_validators.dart';
import 'package:portal_escarlate_app/main.dart';

void main() {
  test('Validação local de e-mail e senha', () {
    expect(AuthValidators.email(''), 'Informe seu e-mail.');
    expect(AuthValidators.email('invalido'), 'Informe um e-mail válido.');
    expect(AuthValidators.email('email@exemplo.com'), isNull);
    expect(AuthValidators.strongPassword('abcdefg1!'), isNull);
    expect(AuthValidators.strongPassword('abc'), 'Ao menos 8 caracteres.');
    expect(AuthValidators.confirm('diferente', 'abcdefg1!'), 'As senhas não conferem.');
  });
  testWidgets('Exibe o progresso 1/6 no login', (tester) async {
    await tester.pumpWidget(const PortalEscarlateApp());
    expect(find.textContaining('AUTENTICAÇÃO '), findsOneWidget);
  });
}
