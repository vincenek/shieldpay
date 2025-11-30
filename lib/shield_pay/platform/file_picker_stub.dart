typedef OnContent = void Function(String content);
typedef OnBytes = void Function(List<int> bytes, String filename);

class WebFilePicker {
  static void pickFile(OnContent onContent) {
    // No-op on non-web platforms.
  }

  static void pickFileBytes(OnBytes onBytes, {String accept = '.csv,text/csv'}) {
    // No-op on non-web platforms.
  }
}
