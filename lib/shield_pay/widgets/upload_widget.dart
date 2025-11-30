import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:tax/shield_pay/platform/file_picker_stub.dart'
  if (dart.library.html) 'package:tax/shield_pay/platform/file_picker_web.dart' as file_picker;
import '../services/pdf_remote_service.dart';
import '../models/invoice.dart';
import '../services/scan_engine.dart';
import '../models/scan_result.dart';
import '../services/history_service.dart';

class UploadWidget extends StatefulWidget {
  final ValueChanged<ScanResult>? onScanned;
  const UploadWidget({super.key, this.onScanned});

  @override
  State<UploadWidget> createState() => _UploadWidgetState();
}

class _UploadWidgetState extends State<UploadWidget> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _acc = TextEditingController();
  final _amount = TextEditingController();
  final _email = TextEditingController();
  final _domain = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _acc.dispose();
    _amount.dispose();
    _email.dispose();
    _domain.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final invoice = Invoice(
      payeeName: _name.text.trim(),
      accountNumber: _acc.text.trim(),
      amount: double.tryParse(_amount.text.trim()) ?? 0.0,
      email: _email.text.trim(),
      vendorDomain: _domain.text.trim(),
      invoiceDate: DateTime.now(),
    );
    _runScan(invoice);
  }

  Future<void> _importPdf() async {
    if (!kIsWeb) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a PDF to import...')));
    try {
      file_picker.WebFilePicker.pickFileBytes((bytes, filename) async {
        if (bytes.isEmpty) return;
        final svc = PdfRemoteService();
        try {
          final map = await svc.extractFromPdf(Uint8List.fromList(bytes), filename);
          // populate fields heuristically
          final emails = (map['emails'] as List<dynamic>?)?.cast<String>() ?? [];
          final ibans = (map['ibans'] as List<dynamic>?)?.cast<String>() ?? [];
          final amounts = (map['amounts'] as List<dynamic>?)?.cast<String>() ?? [];
          if (!mounted) return;
          if (emails.isNotEmpty) _email.text = emails.first;
          if (ibans.isNotEmpty) _acc.text = ibans.first;
          if (amounts.isNotEmpty) _amount.text = amounts.first.replaceAll(',', '.');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imported PDF fields (verify before sending)')));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
        }
      }, accept: '.pdf,application/pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import error: $e')));
    }
  }

  Future<void> _runScan(Invoice invoice) async {
    final history = await loadHistory();
    final result = await ScanEngine.scan(invoice, history: history);
    if (!mounted) return;
    if (widget.onScanned != null) {
      widget.onScanned!(result);
    } else {
      showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Scan Result'), content: Text('Score: ${result.score}\nReasons: ${result.reasons.join('\n')}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Payee name')),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton(onPressed: _submit, child: const Text('Scan')),
              const SizedBox(width: 8),
              if (kIsWeb) OutlinedButton(onPressed: _importPdf, child: const Text('Import PDF (web)')),
            ],),
            const SizedBox(height: 8),
            TextFormField(controller: _amount, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email (optional)')),
            const SizedBox(height: 8),
            TextFormField(controller: _domain, decoration: const InputDecoration(labelText: 'Vendor domain (optional)')),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }
}
