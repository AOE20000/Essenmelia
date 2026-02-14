import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

import 'file_service_stub.dart'
    if (dart.library.io) 'file_service_io.dart'
    if (dart.library.html) 'file_service_web.dart';

class FileService {
  static Future<void> exportData(String jsonContent, String fileName) async {
    await saveJsonFile(jsonContent, fileName);
  }

  static Future<void> exportZip(Uint8List bytes, String fileName) async {
    await saveZipFile(bytes, fileName);
  }

  static Future<String> readData(PlatformFile file) async {
    return await readJsonFile(file);
  }

  static Future<Uint8List?> readZip(PlatformFile file) async {
    return await readZipFile(file);
  }
}
