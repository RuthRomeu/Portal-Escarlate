import 'package:portal_core/portal_core.dart';
import 'package:test/test.dart';

void main() {
  test('token ausente ou incorreto é recusado', () {
    expect(safeTokenEquals(null, 'secret'), isFalse);
    expect(safeTokenEquals('other', 'secret'), isFalse);
    expect(safeTokenEquals('secret', 'secret'), isTrue);
  });
}
