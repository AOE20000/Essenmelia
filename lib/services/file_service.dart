import 'package:file_picker/file_picker.dart';

import 'file_service_stub.dart'
    if (dart.library.io) 'file_service_io.dart'
    if (dart.library.html) 'file_service_web.dart';

class FileService {
  static Future<void> exportData(String jsonContent, String fileName) async {
    await saveJsonFile(jsonContent, fileName);
  }

  static Future<String> readData(PlatformFile file) async {
    return await readJsonFile(file);
  }
}
