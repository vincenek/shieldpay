// Conditional export: web implementation uses `dart:html`, otherwise use stub.
export 'history_service_stub.dart' if (dart.library.html) 'history_service_web.dart';
// Simple history service (in-memory). For web this can be replaced with a localStorage-backed implementation.
import 'dart:async';
import 'dart:convert';
import 'settings_service.dart';
import 'encrypted_storage.dart';
import 'telemetry_service.dart';

final List<Map<String, dynamic>> _inMemoryHistory = [];

Future<void> saveScanToHistory(Map<String, dynamic> scan) async {
  final entry = Map<String, dynamic>.from(scan);
  entry.putIfAbsent('timestamp', () => DateTime.now().toIso8601String());
  entry.putIfAbsent('verified', () => false);
  _inMemoryHistory.add(entry);
  // Enforce retention setting if provided
  try {
    final max = SettingsService.instance.current.maxHistoryEntries;
    if (max > 0 && _inMemoryHistory.length > max) {
      // keep most recent entries
      final keep = _inMemoryHistory.sublist(_inMemoryHistory.length - max);
      _inMemoryHistory
        ..clear()
        ..addAll(keep);
    }
  } catch (_) {}
  // telemetry (best-effort)
  try {
    await TelemetryService.logEvent('save_scan', {'payee': entry['payeeName'] ?? '', 'score': entry['score'] ?? 0});
  } catch (_) {}
}

Future<List<Map<String, dynamic>>> loadHistory() async {
  // If encryption enabled and stored as encrypted blob elsewhere, this in-memory stub won't handle it.
  return _inMemoryHistory.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<void> clearHistory() async {
  _inMemoryHistory.clear();
}

Future<void> markScanVerified(Map<String, dynamic> scan) async {
  // Find the first entry that matches payee, account and amount and set verified=true
  for (var i = 0; i < _inMemoryHistory.length; i++) {
    final e = _inMemoryHistory[i];
    if ((e['payeeName'] ?? '') == (scan['payeeName'] ?? '') && (e['accountNumber'] ?? '') == (scan['accountNumber'] ?? '') && (e['amount'] ?? '') == (scan['amount'] ?? '')) {
      e['verified'] = true;
      return;
    }
  }
}

String exportHistoryCsv(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return '';
  final headers = rows.first.keys.toList();
  final buffer = StringBuffer();
  buffer.writeln(headers.join(','));
  for (final r in rows) {
    buffer.writeln(headers.map((h) => '${r[h] ?? ''}').join(','));
  }
  return buffer.toString();
}

void downloadCsvFile(String csv, String filename) {
  // No-op in this simple implementation. Web implementation can use dart:html.
}

void downloadJsonFile(String json, String filename) {
  // No-op fallback for non-web platforms.
}

Future<void> importCsvFromFilePicker() async {
  // No-op fallback for non-web platforms.
}

String exportHistoryJson(List<Map<String, dynamic>> rows, {bool anonymize = true}) {
  final List<Map<String, dynamic>> out = [];
  for (final r in rows) {
    final copy = Map<String, dynamic>.from(r);
    if (anonymize) {
      final acc = (copy['accountNumber'] ?? '').toString();
      if (acc.length > 4) copy['accountNumber'] = '****${acc.substring(acc.length - 4)}';
      final pn = (copy['payeeName'] ?? '').toString();
      if (pn.isNotEmpty) copy['payeeName'] = pn.split(' ').take(2).map((s) => s.isNotEmpty ? s[0] : '').join() + '...';
    }
    out.add(copy);
  }
  return jsonEncode(out);
}

// Platform-agnostic CSV import is intentionally a no-op here; web implementation provides file handling.
Future<void> importCsvTextToHistory(String csvText) async {
  // no-op: platform-specific implementations will provide parsing and saving.
}
