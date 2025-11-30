import 'package:flutter_test/flutter_test.dart';
import 'package:tax/shield_pay/services/csv_parser.dart';

void main() {
  test('parse CSV with quoted fields and commas', () {
    final csv = 'payeeName,accountNumber,amount,email,vendorDomain\n"Doe, Inc",GB82WEST12345698765432,123.45,billing@doe.com,doe.com';
    final rows = CsvParser.parseCsvToMaps(csv);
    expect(rows.length, 1);
    final row = rows.first;
    expect(row['payeeName'], 'Doe, Inc');
    expect(row['accountNumber'], 'GB82WEST12345698765432');
    expect(row['amount'], '123.45');
  });
}
