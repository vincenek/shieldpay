// Web-only helpers: use `dart:html` in web builds.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'package:tax/shield_pay/services/csv_parser.dart';
import 'package:tax/shield_pay/services/settings_service.dart';
import 'package:tax/shield_pay/services/encrypted_storage.dart';
import 'package:tax/shield_pay/services/telemetry_service.dart';

const _kHistoryKey = 'shieldpay_history_v1';

Future<void> saveScanToHistory(Map<String, dynamic> scan) async {
  final raw = html.window.localStorage[_kHistoryKey];
  final list = raw == null ? <dynamic>[] : json.decode(raw) as List<dynamic>;
  final entry = Map<String, dynamic>.from(scan);
  entry.putIfAbsent('timestamp', () => DateTime.now().toIso8601String());
  entry.putIfAbsent('verified', () => false);
  list.add(entry);
  // If encryption enabled, store encrypted JSON blob
  final settings = SettingsService.instance.current;
  if (settings.encryptedStorageEnabled) {
    // Require the in-memory key to be set — do not silently fall back to plaintext.
    if (!EncryptedStorageService.isKeySet) {
      throw StateError('Encrypted storage is enabled but no passphrase is unlocked for this session');
    }
    final jsonStr = json.encode(list);
    final payload = EncryptedStorageService.encryptJson(jsonStr);
    html.window.localStorage[_kHistoryKey] = payload;
  } else {
    html.window.localStorage[_kHistoryKey] = json.encode(list);
  }
  // telemetry
  try {
    await TelemetryService.logEvent('save_scan', {'payee': entry['payeeName'] ?? '', 'score': entry['score'] ?? 0});
  } catch (_) {}
}

Future<List<Map<String, dynamic>>> loadHistory() async {
  final raw = html.window.localStorage[_kHistoryKey];
  if (raw == null) return [];
  try {
    final settings = SettingsService.instance.current;
    if (settings.encryptedStorageEnabled) {
      // If encryption is enabled but the key is not unlocked, return empty and let
      // the UI prompt user to unlock. Avoid decrypt attempts without key.
      if (!EncryptedStorageService.isKeySet) return [];
      final decoded = EncryptedStorageService.decryptJson(raw);
      final list = json.decode(decoded) as List<dynamic>;
      return List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e)));
    }
    final list = json.decode(raw) as List<dynamic>;
    return List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e)));
  } catch (_) {
    return [];
  }
}

Future<void> clearHistory() async {
  html.window.localStorage.remove(_kHistoryKey);
}

Future<void> markScanVerified(Map<String, dynamic> scan) async {
  final raw = html.window.localStorage[_kHistoryKey];
  if (raw == null) return;
  final list = json.decode(raw) as List<dynamic>;
  for (var i = 0; i < list.length; i++) {
    final e = Map<String, dynamic>.from(list[i]);
    if ((e['payeeName'] ?? '') == (scan['payeeName'] ?? '') && (e['accountNumber'] ?? '') == (scan['accountNumber'] ?? '') && (e['amount'] ?? '') == (scan['amount'] ?? '')) {
      e['verified'] = true;
      list[i] = e;
      html.window.localStorage[_kHistoryKey] = json.encode(list);
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
    buffer.writeln(headers.map((h) => _escapeCsv('${r[h] ?? ''}')).join(','));
  }
  return buffer.toString();
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
  return json.encode(out);
}

void downloadJsonFile(String json, String filename) {
  final blob = html.Blob([json], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<void> importCsvTextToHistory(String csvText) async {
  final maps = CsvParser.parseCsvToMaps(csvText);
  for (final m in maps) {
    final entry = <String, dynamic>{
      'payeeName': m['payeeName'] ?? m['Payee'] ?? '',
      'accountNumber': m['accountNumber'] ?? m['Account'] ?? m['IBAN'] ?? '',
      'amount': m['amount'] ?? m['Amount'] ?? '0',
      'email': m['email'] ?? m['Email'] ?? '',
      'vendorDomain': m['vendorDomain'] ?? m['Vendor'] ?? '',
    };
    await saveScanToHistory(entry);
  }
}

Future<void> importCsvFromFilePicker() async {
  final input = html.FileUploadInputElement();
  input.accept = '.csv,text/csv';
  input.multiple = false;
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return;
  final file = files.first;
  final reader = html.FileReader();
  reader.readAsText(file);
  await reader.onLoad.first;
  final text = reader.result as String;
  await importCsvTextToHistory(text);
}

String _escapeCsv(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

void downloadCsvFile(String csv, String filename) {
  final blob = html.Blob([csv], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

void downloadPdfBytes(List<int> bytes, String filename) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
