import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/event.dart';

class StorageService {
  /// 下载并保存远程图片到本地应用目录
  /// 如果是本地路径则直接返回，如果下载失败则返回原 URL
  static Future<String> downloadAndSaveImage(String url) async {
    if (url.isEmpty || !url.startsWith('http')) {
      return url;
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint('StorageService: Failed to download image ($url), status: ${response.statusCode}');
        return url;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'event_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // 获取文件扩展名，默认为 .jpg
      String extension = p.extension(Uri.parse(url).path);
      if (extension.isEmpty) extension = '.jpg';
      
      // 生成唯一文件名
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}$extension';
      final file = File(p.join(imagesDir.path, fileName));
      
      await file.writeAsBytes(response.bodyBytes);
      debugPrint('StorageService: Downloaded image to ${file.path}');
      
      return file.path;
    } catch (e) {
      debugPrint('StorageService: Error downloading image: $e');
      return url;
    }
  }

  /// 清理不再被任何数据库引用的“孤儿”图片文件
  static Future<int> cleanupOrphanImages() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'event_images'));

      if (!await imagesDir.exists()) {
        return 0;
      }

      // 1. 获取所有数据库前缀
      if (!Hive.isBoxOpen('essenmelia_meta')) {
        await Hive.openBox('essenmelia_meta');
      }
      final metaBox = Hive.box('essenmelia_meta');
      final prefixes = List<String>.from(
        metaBox.get('db_list', defaultValue: ['main']),
      );

      final referencedBasenames = <String>{};

      // 2. 遍历所有数据库，收集被引用的图片文件名
      for (final prefix in prefixes) {
        final boxName = '${prefix}_events';
        bool wasOpen = Hive.isBoxOpen(boxName);
        
        // 确保盒子已打开
        Box<Event> box;
        try {
          box = wasOpen ? Hive.box<Event>(boxName) : await Hive.openBox<Event>(boxName);
        } catch (e) {
          debugPrint('Storage Service: Could not open box $boxName for cleanup: $e');
          continue;
        }

        for (final event in box.values) {
          final url = event.imageUrl;
          if (url != null &&
              url.isNotEmpty &&
              !url.startsWith('http') &&
              !url.startsWith('data:')) {
            // 使用 basename 比较，以兼容 iOS 路径变化
            referencedBasenames.add(p.basename(url));
          }
        }

        // 如果是为了清理而打开的，清理完后关闭以节省内存
        if (!wasOpen) {
          await box.close();
        }
      }

      // 3. 遍历文件夹中的所有文件
      int deletedCount = 0;
      final List<FileSystemEntity> files = await imagesDir.list().toList();

      for (final file in files) {
        if (file is File) {
          final fileName = p.basename(file.path);
          // 如果文件不在任何数据库的引用列表中，且不是刚刚创建的，则删除
          if (!referencedBasenames.contains(fileName)) {
            // 额外检查：避免删除刚刚创建但还没存入 DB 的文件（比如 10 分钟内的）
            final lastModified = await file.lastModified();
            if (DateTime.now().difference(lastModified).inMinutes > 10) {
              await file.delete();
              deletedCount++;
              debugPrint('Storage Service: Deleting orphan image: ${file.path}');
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
