import 'package:flutter_test/flutter_test.dart';
import 'package:tax/shield_pay/services/scan_engine.dart';

void main() {
  test('jaro-winkler similarity for similar names', () {
    final a = 'Acme Supplies Ltd';
    final b = 'acme-supplies.com';
    final sim = ScanEngine.jaroWinkler(a, b);
    expect(sim > 0.5, true);
  });

  test('jaro-winkler similarity for different names', () {
    final similar = ScanEngine.jaroWinkler('Acme Supplies Ltd', 'acme-supplies.com');
    final different = ScanEngine.jaroWinkler('Contoso Limited', 'acme-supplies.com');
    expect(similar > different, true);
  });
}
