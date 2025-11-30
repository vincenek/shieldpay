// Web-only helpers used when running as Flutter Web.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:tax/shield_pay/platform/file_picker_stub.dart'
  if (dart.library.html) 'package:tax/shield_pay/platform/file_picker_web.dart' as file_picker;
import '../models/invoice.dart';
import '../services/scan_engine.dart';
import '../services/history_service.dart';
import '../services/csv_parser.dart';

// Web-only import
// dart:html access is provided via conditional import above (file_picker_web/file_picker_stub).

class BatchUploadWidget extends StatefulWidget {
  const BatchUploadWidget({super.key});

  @override
  State<BatchUploadWidget> createState() => _BatchUploadWidgetState();
}

class _BatchUploadWidgetState extends State<BatchUploadWidget> {
  final _csvCtrl = TextEditingController();
  bool _processing = false;

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  Future<void> _processCsvText(String text) async {
    setState(() => _processing = true);
    final rows = CsvParser.parseCsvToMaps(text);
    if (rows.isEmpty) { setState(() => _processing = false); return; }
    final results = <Map<String, dynamic>>[];
    for (final map in rows) {
      final invoice = Invoice(
        payeeName: map['payeeName'] ?? '',
        accountNumber: map['accountNumber'] ?? '',
        amount: double.tryParse(map['amount'] ?? '') ?? 0.0,
        email: map['email'] ?? '',
        vendorDomain: map['vendorDomain'] ?? '',
        invoiceDate: DateTime.tryParse(map['invoiceDate'] ?? '') ?? DateTime.now(),
      );
      final history = await loadHistory();
      final res = await ScanEngine.scan(invoice, history: history);
      final row = {...invoice.toJson(), 'score': res.score, 'reasons': res.reasons.join(' | ')};
      results.add(row);
      await saveScanToHistory(row);
    }
    setState(() => _processing = false);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Batch Results')), body: Padding(padding: const EdgeInsets.all(12), child: ListView(children: results.map((r) => Card(child: ListTile(title: Text('${r['payeeName'] ?? ''}'), subtitle: Text('Score: ${r['score']} — ${r['reasons']}')))).toList())))));
  }

  // CSV parsing is handled by `CsvParser` service.

  void _pickFileWeb() {
    if (!kIsWeb) return;
    file_picker.WebFilePicker.pickFile((content) {
      _csvCtrl.text = content;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Batch CSV Upload (headers: payeeName,accountNumber,amount,email,vendorDomain,invoiceDate)'),
          const SizedBox(height: 8),
          TextField(controller: _csvCtrl, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'CSV content...')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            ElevatedButton(onPressed: _processing ? null : () => _processCsvText(_csvCtrl.text), child: _processing ? const Text('Processing...') : const Text('Parse & Scan')),
            if (kIsWeb) OutlinedButton(onPressed: _pickFileWeb, child: const Text('Pick CSV file')),
          ])
        ]),
      ),
    );
  }
}
