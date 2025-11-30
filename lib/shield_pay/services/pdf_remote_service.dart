import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class PdfRemoteService {
  final String baseUrl;
  PdfRemoteService({this.baseUrl = 'http://localhost:8080'});

  /// Upload PDF bytes to server /extract endpoint as multipart/form-data
  Future<Map<String, dynamic>> extractFromPdf(Uint8List bytes, String filename) async {
    final uri = Uri.parse('$baseUrl/extract');
    final req = http.MultipartRequest('POST', uri);
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: null));
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) throw Exception('Remote extraction failed: ${resp.statusCode}');
    return json.decode(resp.body) as Map<String, dynamic>;
  }
}
