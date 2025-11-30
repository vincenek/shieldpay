import 'package:flutter_test/flutter_test.dart';
import 'package:tax/shield_pay/services/scan_engine.dart';
import 'package:tax/shield_pay/models/invoice.dart';

void main() {
  test('valid IBAN passes checksum', () async {
    final inv = Invoice(
      payeeName: 'Test Ltd',
      accountNumber: 'GB82WEST12345698765432',
      amount: 100.0,
      email: 'billing@test.com',
      vendorDomain: 'test.com',
      invoiceDate: DateTime.now(),
    );
    final res = await ScanEngine.scan(inv, history: []);
    expect(res.details['ibanOk'], true);
    expect(res.score < 50, true);
  });

  test('invalid IBAN fails checksum', () async {
    final inv = Invoice(
      payeeName: 'Bad Co',
      accountNumber: 'GB82WEST12345698765433',
      amount: 50.0,
      email: 'bad@co.com',
      vendorDomain: 'co.com',
      invoiceDate: DateTime.now(),
    );
    final res = await ScanEngine.scan(inv, history: []);
    expect(res.details['ibanOk'], false);
    expect(res.score >= 40, true);
  });

  test('amount outlier detected with history', () async {
    final history = List.generate(6, (i) => {
      'payeeName': 'Acme',
      'vendorDomain': 'acme.com',
      'accountNumber': 'GB82WEST12345698765432',
      'amount': '${100 + i * 5}',
    });
    final inv = Invoice(
      payeeName: 'Acme',
      accountNumber: 'GB82WEST12345698765432',
      amount: 10000.0,
      email: 'pay@acme.com',
      vendorDomain: 'acme.com',
      invoiceDate: DateTime.now(),
    );
    final res = await ScanEngine.scan(inv, history: history);
    // Outlier should contribute to score
    expect(res.reasons.any((r) => r.toLowerCase().contains('outlier')), true);
    expect(res.score > 0, true);
  });
}
