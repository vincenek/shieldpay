class CsvParser {
  /// Split a CSV line into columns, handling quoted fields and escaped quotes.
  static List<String> splitLine(String line) {
    final cols = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (ch == ',' && !inQuotes) {
        cols.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(ch);
    }
    cols.add(buffer.toString());
    return cols.map((s) => s.trim()).toList();
  }

  /// Parse CSV text into a list of maps using the first non-empty line as headers.
  /// Returns empty list if no rows.
  static List<Map<String, String>> parseCsvToMaps(String text) {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];
    final headers = splitLine(lines.first);
    final rows = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      final cols = splitLine(lines[i]);
      final map = <String, String>{};
      for (var j = 0; j < headers.length && j < cols.length; j++) {
        map[headers[j]] = cols[j];
      }
      rows.add(map);
    }
    return rows;
  }
}
