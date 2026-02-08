// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '埃森梅莉亚';

  @override
  String get settings => '设置';

  @override
  String get darkMode => '深色模式';

  @override
  String get collapseImages => '折叠图片';

  @override
  String get itemsPerRow => '每行卡片数';

  @override
  String get databaseManager => '数据库管理';

  @override
  String get manageTags => '标签管理';

  @override
  String get exportData => '导出数据 (JSON)';

  @override
  String get importData => '导入数据 (JSON)';

  @override
  String get deleteAllData => '删除所有数据';

  @override
  String get deleteAllDataConfirmTitle => '确认删除所有数据？';

  @override
  String get deleteAllDataConfirmContent => '此操作无法撤销。所有数据将永久丢失。';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get create => '创建';

  @override
  String get switchDb => '切换';

  @override
  String get availableDatabases => '可用数据库';

  @override
  String get createNewDatabase => '创建新数据库';

  @override
  String get databaseName => '数据库名称';

  @override
  String get invalidName => '无效名称。请使用字母、数字、- 或 _';

  @override
  String get searchEvents => '搜索事件...';

  @override
  String get noEventsFound => '未找到相关事件';

  @override
  String get sort => '排序';

  @override
  String get newestFirst => '最新创建';

  @override
  String get oldestFirst => '最早创建';

  @override
  String get titleAZ => '标题 (A-Z)';

  @override
  String get titleZA => '标题 (Z-A)';

  @override
  String get progressHighLow => '进度 (高到低)';

  @override
  String get progressLowHigh => '进度 (低到高)';

  @override
  String get selected => '已选中';

  @override
  String get deleteSelected => '删除选中项？';

  @override
  String deleteSelectedCount(int count) {
    return '确认删除 $count 个项目？';
  }

  @override
  String get steps => '步骤';

  @override
  String stepsCount(int completed, int total) {
    return '$completed / $total 步骤';
  }

  @override
  String get language => '语言';

  @override
  String get system => '跟随系统';

  @override
  String get english => 'English';

  @override
  String get chinese => '简体中文';
}
