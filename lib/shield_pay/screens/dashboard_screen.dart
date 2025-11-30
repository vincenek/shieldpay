import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../services/history_service.dart';
import '../services/export_service.dart';

// no additional dart: imports required

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await loadHistory();
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _downloadCsv() async {
    final csv = exportHistoryCsv(_rows);
    downloadCsvFile(csv, 'shieldpay_history.csv');
  }

  Future<void> _downloadPdf() async {
    final bytes = await generatePdfReport(_rows);
    downloadPdfBytes(bytes, 'shieldpay_report.pdf');
  }

  Future<void> _downloadJson() async {
    final json = exportHistoryJson(_rows, anonymize: true);
    // web implementation exposes downloadJsonFile; on other platforms we just show clipboard
    try {
      // ignore: avoid_dynamic_calls
      downloadJsonFile(json, 'shieldpay_history.json');
    } catch (_) {
      // fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON copied to clipboard')));
    }
  }

  Future<void> _importCsv() async {
    if (kIsWeb) {
      try {
        // Use web helper
        // ignore: avoid_dynamic_calls
        await importCsvFromFilePicker();
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV imported')));
        return;
      } catch (e) {
        // fallthrough to generic handler
      }
    }
    // Non-web: show instructions dialog
    if (!mounted) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Import CSV'), content: const Text('Import CSV is currently supported only on web build. Paste CSV text into the console for now.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  ElevatedButton(onPressed: _downloadCsv, child: const Text('Download CSV')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _downloadPdf, child: const Text('Download PDF')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _downloadJson, child: const Text('Download JSON')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _importCsv, child: const Text('Import CSV')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () async { await clearHistory(); await _load(); }, child: const Text('Clear History')),
                ]),
                const SizedBox(height: 12),
                Expanded(child: ListView.builder(itemCount: _rows.length, itemBuilder: (context, i) {
                  final r = _rows[i];
                  final score = r['score'] ?? 0;
                  return Card(child: ListTile(title: Text('${r['payeeName'] ?? ''}'), subtitle: Text('Score: $score — ${r['reasons'] ?? ''}')));
                }))
              ]),
      ),
    );
  }
}
