import 'package:flutter_test/flutter_test.dart';
import 'package:tax/shield_pay/services/csv_parser.dart';
import 'package:tax/shield_pay/services/history_service.dart';

void main() {
  test('CSV batch import adds rows to history', () async {
    await clearHistory();
    final csv = 'payeeName,accountNumber,amount,email,vendorDomain\n' +
        'Acme,GB82WEST12345698765432,100.00,pay@acme.com,acme.com\n' +
        'Contoso,DE89370400440532013000,520.00,accounts@contoso.com,contoso.com\n';
    final rows = CsvParser.parseCsvToMaps(csv);
    for (final r in rows) {
      final entry = {
        'payeeName': r['payeeName'] ?? '',
        'accountNumber': r['accountNumber'] ?? '',
        'amount': r['amount'] ?? '',
        'email': r['email'] ?? '',
        'vendorDomain': r['vendorDomain'] ?? '',
      };
      await saveScanToHistory(entry);
    }
    final hist = await loadHistory();
    expect(hist.length >= 2, true);
    expect(hist.any((e) => (e['payeeName'] ?? '') == 'Acme'), true);
  });
}
