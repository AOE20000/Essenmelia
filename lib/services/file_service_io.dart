import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveJsonFile(String jsonContent, String fileName) async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Database',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputPath != null) {
      final file = File(outputPath);
      await file.writeAsString(jsonContent);
    }
  } else {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(jsonContent);
    await Share.shareXFiles([XFile(file.path)], text: 'Essenmelia Backup');
  }
}

Future<void> saveZipFile(Uint8List bytes, String fileName) async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (outputPath != null) {
      final file = File(outputPath);
      await file.writeAsBytes(bytes);
    }
  } else {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Essenmelia Full Backup');
  }
}

Future<String> readJsonFile(PlatformFile file) async {
  if (file.path != null) {
    final ioFile = File(file.path!);
    return await ioFile.readAsString();
  }
  return '';
}

Future<Uint8List?> readZipFile(PlatformFile file) async {
  if (file.path != null) {
    final ioFile = File(file.path!);
    return await ioFile.readAsBytes();
  } else if (file.bytes != null) {
    return file.bytes;
  }
  return null;
}
