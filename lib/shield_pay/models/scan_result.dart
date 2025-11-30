class ScanResult {
  final int score;
  final List<String> reasons;
  final Map<String, dynamic> details;

  ScanResult({required this.score, required this.reasons, Map<String, dynamic>? details}) : details = details ?? {};
}
