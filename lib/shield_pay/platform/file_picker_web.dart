// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

typedef OnContent = void Function(String content);
typedef OnBytes = void Function(List<int> bytes, String filename);

class WebFilePicker {
  static void pickFile(OnContent onContent) {
    final upload = html.FileUploadInputElement();
    upload.accept = '.csv,text/csv';
    upload.click();
    upload.onChange.listen((e) {
      final files = upload.files;
      if (files == null || files.isEmpty) return;
      final f = files.first;
      final reader = html.FileReader();
      reader.onLoad.listen((ev) {
        final content = reader.result;
        if (content is String) onContent(content);
      });
      reader.readAsText(f);
    });
  }

  static void pickFileBytes(OnBytes onBytes, {String accept = '.csv,text/csv'}) {
    final upload = html.FileUploadInputElement();
    upload.accept = accept;
    upload.click();
    upload.onChange.listen((e) {
      final files = upload.files;
      if (files == null || files.isEmpty) return;
      final f = files.first;
      final reader = html.FileReader();
      reader.onLoad.listen((ev) {
        final content = reader.result;
        // On web, readAsArrayBuffer returns an ArrayBuffer which maps to a ByteBuffer-like
        // object accessible via `asUint8List()` when cast to dynamic.
        try {
          final dyn = content as dynamic;
          final uint8 = dyn.asUint8List();
          onBytes(uint8.cast<int>().toList(), f.name);
        } catch (_) {
          // fallback: if the reader returned text, return code units
          if (content is String) onBytes(content.codeUnits, f.name);
        }
      });
      reader.readAsArrayBuffer(f);
    });
  }
}
