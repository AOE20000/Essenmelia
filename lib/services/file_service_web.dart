import 'dart:convert';
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';

Future<void> saveJsonFile(String jsonContent, String fileName) async {
  final bytes = utf8.encode(jsonContent);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  // ignore: unused_local_variable
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<String> readJsonFile(PlatformFile file) async {
  if (file.bytes != null) {
    return utf8.decode(file.bytes!);
  }
  return '';
}
