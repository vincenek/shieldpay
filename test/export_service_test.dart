import 'package:flutter_test/flutter_test.dart';
import 'package:tax/shield_pay/services/export_service.dart';

void main() {
  test('generatePdfReport returns bytes', () async {
    final rows = [
      {'payeeName': 'A', 'accountNumber': 'GB82WEST1234', 'amount': '100'},
      {'payeeName': 'B', 'accountNumber': 'GB82WEST5678', 'amount': '200'},
    ];
    final bytes = await generatePdfReport(rows);
    expect(bytes, isNotNull);
    expect(bytes.length, greaterThan(0));
  });
}
