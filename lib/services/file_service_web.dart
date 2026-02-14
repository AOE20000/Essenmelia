import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

Future<void> saveJsonFile(String jsonContent, String fileName) async {
  // Create a Blob from the JSON string
  final blob = web.Blob([jsonContent.toJS].toJS);
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();

  web.URL.revokeObjectURL(url);
}

Future<void> saveZipFile(Uint8List bytes, String fileName) async {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();

  web.URL.revokeObjectURL(url);
}

Future<String> readJsonFile(PlatformFile file) async {
  if (file.bytes != null) {
    return utf8.decode(file.bytes!);
  }
  return '';
}

Future<Uint8List?> readZipFile(PlatformFile file) async {
  return file.bytes;
}
