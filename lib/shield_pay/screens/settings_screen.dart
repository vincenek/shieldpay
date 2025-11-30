import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/encrypted_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Settings _s;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _s = Settings();
    _load();
  }

  Future<void> _load() async {
    await SettingsService.instance.load();
    setState(() {
      _s = SettingsService.instance.current;
      _loaded = true;
    });
  }

  Future<void> _setEncryptionPassphrase() async {
    final pass = await showDialog<String>(context: context, builder: (ctx) {
      String val = '';
      return AlertDialog(
        title: const Text('Set encryption passphrase'),
        content: TextField(obscureText: true, onChanged: (v) => val = v, decoration: const InputDecoration(labelText: 'Passphrase')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, val), child: const Text('Save'))],
      );
    });
    if (pass != null && pass.isNotEmpty) {
      // derive key using PBKDF2 and persist salt in settings
      final salt = EncryptedStorageService.createAndSetPassphrase(pass);
      SettingsService.instance.current.encryptionSalt = salt;
      setState(() => _s.encryptedStorageEnabled = true);
      await SettingsService.instance.save();
    }
  }

  Future<void> _save() async {
    SettingsService.instance.current.ibanWeight = _s.ibanWeight;
    SettingsService.instance.current.freeEmailWeight = _s.freeEmailWeight;
    SettingsService.instance.current.vendorMismatchWeight = _s.vendorMismatchWeight;
    SettingsService.instance.current.accountNewWeight = _s.accountNewWeight;
    SettingsService.instance.current.outlierWeight = _s.outlierWeight;
    SettingsService.instance.current.emailVendorReduction = _s.emailVendorReduction;
    SettingsService.instance.current.similarityThreshold = _s.similarityThreshold;
    SettingsService.instance.current.maxHistoryEntries = _s.maxHistoryEntries;
    SettingsService.instance.current.allowRemotePdf = _s.allowRemotePdf;
    SettingsService.instance.current.telemetryEnabled = _s.telemetryEnabled;
    SettingsService.instance.current.anonymizeExports = _s.anonymizeExports;
    await SettingsService.instance.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged, {String? unit}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(unit != null ? '${value.toStringAsFixed(2)} $unit' : value.toStringAsFixed(2))]),
      Slider(value: value, min: min, max: max, divisions: 100, onChanged: onChanged),
      const SizedBox(height: 8),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loaded ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Heuristic weights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _buildSlider('IBAN weight', _s.ibanWeight, 0.0, 3.0, (v) => setState(() => _s.ibanWeight = v)),
            _buildSlider('Free-email weight', _s.freeEmailWeight, 0.0, 3.0, (v) => setState(() => _s.freeEmailWeight = v)),
            _buildSlider('Vendor-mismatch weight', _s.vendorMismatchWeight, 0.0, 3.0, (v) => setState(() => _s.vendorMismatchWeight = v)),
            _buildSlider('New-account weight', _s.accountNewWeight, 0.0, 3.0, (v) => setState(() => _s.accountNewWeight = v)),
            _buildSlider('Amount-outlier weight', _s.outlierWeight, 0.0, 3.0, (v) => setState(() => _s.outlierWeight = v)),
            _buildSlider('Email->Vendor reduction', _s.emailVendorReduction, 0.0, 10.0, (v) => setState(() => _s.emailVendorReduction = v)),
            _buildSlider('Name/domain similarity threshold', _s.similarityThreshold, 0.0, 1.0, (v) => setState(() => _s.similarityThreshold = v)),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Privacy & Retention', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextFormField(initialValue: _s.maxHistoryEntries.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max history entries (0 = unlimited)'), onChanged: (v) => setState(() => _s.maxHistoryEntries = int.tryParse(v) ?? 0))),
            ]),
            SwitchListTile(value: _s.anonymizeExports, title: const Text('Anonymize exports'), subtitle: const Text('Mask account numbers and shorten payee names in exports.'), onChanged: (v) => setState(() => _s.anonymizeExports = v)),
            SwitchListTile(value: _s.allowRemotePdf, title: const Text('Allow remote PDF extraction'), subtitle: const Text('Enable only if you trust the remote extractor.'), onChanged: (v) => setState(() => _s.allowRemotePdf = v)),
            SwitchListTile(value: _s.telemetryEnabled, title: const Text('Enable telemetry (opt-in)'), subtitle: const Text('Share anonymous usage data to help improve ShieldPay.'), onChanged: (v) => setState(() => _s.telemetryEnabled = v)),
            SwitchListTile(value: _s.encryptedStorageEnabled, title: const Text('Enable encrypted local storage'), subtitle: const Text('Encrypt history locally with a passphrase (session key kept in memory).'), onChanged: (v) async { if (v) { await _setEncryptionPassphrase(); } else { EncryptedStorageService.clearKey(); setState(() => _s.encryptedStorageEnabled = false); } }),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _save, child: const Text('Save Settings')),
          ]),
        ),
      ) : const Center(child: CircularProgressIndicator()),
    );
  }
}
