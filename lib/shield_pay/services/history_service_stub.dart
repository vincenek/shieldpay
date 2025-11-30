import 'dart:async';

final List<Map<String, dynamic>> _memoryHistory = [];

Future<void> saveScanToHistory(Map<String, dynamic> scan) async {
  _memoryHistory.add(Map<String, dynamic>.from(scan));
}

Future<List<Map<String, dynamic>>> loadHistory() async {
  return _memoryHistory.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<void> clearHistory() async {
  _memoryHistory.clear();
}

String exportHistoryCsv(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return '';
  final headers = rows.first.keys.toList();
  final buffer = StringBuffer();
  buffer.writeln(headers.join(','));
  for (final r in rows) {
    buffer.writeln(headers.map((h) => _escapeCsv('${r[h] ?? ''}')).join(','));
  }
  return buffer.toString();
}

String _escapeCsv(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

void downloadCsvFile(String csv, String filename) {
  // stub: no-op on non-web platforms
}

// Simple export to bytes for non-web (could be used by native file APIs later)
List<int> exportCsvBytes(String csv) => csv.codeUnits;

void downloadPdfBytes(List<int> bytes, String filename) {
  // no-op on non-web
}
