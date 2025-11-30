import 'package:flutter/material.dart';

class BatchResultsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  const BatchResultsScreen({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch Results')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, i) {
            final r = results[i];
            return Card(
              child: ListTile(title: Text('${r['payeeName'] ?? ''}'), subtitle: Text('Score: ${r['score'] ?? ''}')),
            );
          },
        ),
      ),
    );
  }
}
