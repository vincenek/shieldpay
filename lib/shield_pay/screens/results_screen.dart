import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scan_result.dart';
import '../services/history_service.dart';

class ResultsScreen extends StatelessWidget {
  final ScanResult result;
  const ResultsScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Score: ${result.score}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Reasons:'),
          ...result.reasons.map((r) => ListTile(title: Text(r))),
          const SizedBox(height: 8),
          const Text('Details:'),
          Text(result.details.toString()),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton.icon(onPressed: () {
              final acc = result.details['accountNumber'] ?? '';
              Clipboard.setData(ClipboardData(text: acc.toString()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied account to clipboard')));
            }, icon: const Icon(Icons.copy), label: const Text('Copy Account')),
            const SizedBox(width: 8),
            ElevatedButton.icon(onPressed: () {
              final vendor = result.details['vendorDomain'] ?? '';
              Clipboard.setData(ClipboardData(text: vendor.toString()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied vendor domain')));
            }, icon: const Icon(Icons.link), label: const Text('Copy Vendor')),
            const SizedBox(width: 8),
            ElevatedButton.icon(onPressed: () async {
              // mark this scan as verified in history
              await markScanVerified({'payeeName': result.details['payeeName'] ?? '', 'accountNumber': result.details['accountNumber'] ?? '', 'amount': result.details['amount'] ?? ''});
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as verified')));
            }, icon: const Icon(Icons.verified), label: const Text('Mark Verified')),
          ])
        ]),
      ),
    );
  }
}
