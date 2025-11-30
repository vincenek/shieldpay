class Settings {
  double ibanWeight;
  double freeEmailWeight;
  double vendorMismatchWeight;
  double accountNewWeight;
  double outlierWeight;
  double emailVendorReduction;
  double similarityThreshold;
  int maxHistoryEntries;
  bool allowRemotePdf;
  bool telemetryEnabled;
  bool anonymizeExports;
  bool encryptedStorageEnabled;
  String? encryptionSalt;

  Settings({
    this.ibanWeight = 1.0,
    this.freeEmailWeight = 1.0,
    this.vendorMismatchWeight = 1.0,
    this.accountNewWeight = 1.0,
    this.outlierWeight = 1.0,
    this.emailVendorReduction = 0.0,
    this.similarityThreshold = 0.4,
    this.maxHistoryEntries = 0,
    this.allowRemotePdf = false,
    this.telemetryEnabled = false,
    this.anonymizeExports = true,
    this.encryptedStorageEnabled = false,
    this.encryptionSalt,
  });

    Map<String, dynamic> toJson() => {
        'ibanWeight': ibanWeight,
        'freeEmailWeight': freeEmailWeight,
        'vendorMismatchWeight': vendorMismatchWeight,
        'accountNewWeight': accountNewWeight,
        'outlierWeight': outlierWeight,
        'emailVendorReduction': emailVendorReduction,
        'similarityThreshold': similarityThreshold,
      'maxHistoryEntries': maxHistoryEntries,
      'allowRemotePdf': allowRemotePdf,
      'telemetryEnabled': telemetryEnabled,
        'anonymizeExports': anonymizeExports,
        'encryptedStorageEnabled': encryptedStorageEnabled,
        'encryptionSalt': encryptionSalt,
      };

    static Settings fromJson(Map<String, dynamic> j) => Settings(
        ibanWeight: (j['ibanWeight'] ?? 1.0).toDouble(),
        freeEmailWeight: (j['freeEmailWeight'] ?? 1.0).toDouble(),
        vendorMismatchWeight: (j['vendorMismatchWeight'] ?? 1.0).toDouble(),
        accountNewWeight: (j['accountNewWeight'] ?? 1.0).toDouble(),
        outlierWeight: (j['outlierWeight'] ?? 1.0).toDouble(),
      emailVendorReduction: (j['emailVendorReduction'] ?? 0.0).toDouble(),
      similarityThreshold: (j['similarityThreshold'] ?? 0.4).toDouble(),
      maxHistoryEntries: (j['maxHistoryEntries'] ?? 0) as int,
      allowRemotePdf: (j['allowRemotePdf'] ?? false) as bool,
      telemetryEnabled: (j['telemetryEnabled'] ?? false) as bool,
        anonymizeExports: (j['anonymizeExports'] ?? true) as bool,
        encryptedStorageEnabled: (j['encryptedStorageEnabled'] ?? false) as bool,
        encryptionSalt: (j['encryptionSalt'] ?? null) as String?,
      );
}

class SettingsService {
  static final SettingsService instance = SettingsService._internal();
  Settings _current = Settings();

  SettingsService._internal();

  Settings get current => _current;

  Future<void> load() async {
    // Non-web fallback: nothing persisted yet.
    _current = Settings();
  }

  Future<void> save() async {
    // No-op for non-web runtime by default. Can be extended to file store.
  }
}
