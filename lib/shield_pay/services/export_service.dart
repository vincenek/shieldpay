import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

/// Generate a simple PDF report for the given rows (history).
Future<List<int>> generatePdfReport(List<Map<String, dynamic>> rows) async {
  final doc = pw.Document();
  String sanitize(String s) {
    if (s.isEmpty) return s;
    // Replace common Unicode punctuation with ASCII equivalents to avoid font fallback issues.
    return s
        .replaceAll('\u2014', '-') // em-dash
        .replaceAll('\u2013', '-') // en-dash
        .replaceAll('\u2018', "'") // left single quote
        .replaceAll('\u2019', "'") // right single quote
        .replaceAll('\u201C', '"') // left double quote
        .replaceAll('\u201D', '"') // right double quote
        .replaceAll('\u2026', '...'); // ellipsis
  }

  // Try to load a Unicode-capable TTF font from assets (recommended: Noto Sans). If not present, fall back to default.
  pw.Font? embeddedFont;
  try {
    final bytes = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    embeddedFont = pw.Font.ttf(bytes.buffer.asByteData());
  } catch (_) {
    embeddedFont = null;
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    build: (context) {
      return [
        pw.Header(level: 0, child: pw.Text(sanitize('ShieldPay — Scan Report'), style: embeddedFont != null ? pw.TextStyle(font: embeddedFont) : null)),
        pw.Paragraph(text: sanitize('Generated report with ${rows.length} scanned rows.'), style: embeddedFont != null ? pw.TextStyle(font: embeddedFont) : null),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          data: rows.map((r) => r.values.map((v) => sanitize(v?.toString() ?? '')).toList()).toList(),
          headers: rows.isEmpty ? <String>[] : rows.first.keys.toList().map((h) => sanitize(h)).toList(),
          cellStyle: embeddedFont != null ? pw.TextStyle(font: embeddedFont, fontSize: 10) : null,
          headerStyle: embeddedFont != null ? pw.TextStyle(font: embeddedFont, fontSize: 11, fontWeight: pw.FontWeight.bold) : null,
        ),
      ];
    },
  ));

  return doc.save();
}
