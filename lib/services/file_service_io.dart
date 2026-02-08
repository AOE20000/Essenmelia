import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveJsonFile(String jsonContent, String fileName) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsString(jsonContent);
  await Share.shareXFiles([XFile(file.path)], text: 'Essenmelia Backup');
}

Future<String> readJsonFile(PlatformFile file) async {
  if (file.path != null) {
    final ioFile = File(file.path!);
    return await ioFile.readAsString();
  }
  return '';
}
