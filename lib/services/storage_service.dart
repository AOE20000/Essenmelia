import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/event.dart';

class StorageService {
  /// 清理不再被数据库引用的“孤儿”图片文件
  static Future<int> cleanupOrphanImages(String activePrefix) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'event_images'));

      if (!await imagesDir.exists()) {
        return 0;
      }

      // 1. 获取数据库中所有被引用的图片路径
      final box = Hive.box<Event>('${activePrefix}_events');
      final referencedPaths = box.values
          .where((e) => e.imageUrl != null && e.imageUrl!.isNotEmpty)
          .map((e) => e.imageUrl!)
          .toSet();

      // 2. 遍历文件夹中的所有文件
      int deletedCount = 0;
      final List<FileSystemEntity> files = await imagesDir.list().toList();

      for (final file in files) {
        if (file is File) {
          final filePath = file.path;
          // 如果文件不在数据库引用列表中，且不是正在处理的临时文件，则删除
          if (!referencedPaths.contains(filePath)) {
            // 额外检查：避免删除刚刚创建但还没存入 DB 的文件（比如 5 分钟内的）
            final lastModified = await file.lastModified();
            if (DateTime.now().difference(lastModified).inMinutes > 5) {
              await file.delete();
              deletedCount++;
              debugPrint('Storage Service: Deleting orphan image: $filePath');
            }
          }
        }
      }
      return deletedCount;
    } catch (e) {
      debugPrint('Storage Service Error: $e');
      return 0;
    }
  }
}
