// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Essenmelia';

  @override
  String get searchPlaceholder => '搜索事件...';

  @override
  String get select => '选择';

  @override
  String get cancel => '取消';

  @override
  String get newTag => '新建标签';

  @override
  String get tagNameHint => '例如：工作、个人';

  @override
  String get add => '添加';

  @override
  String get renameTag => '重命名标签';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get confirm => '确认';

  @override
  String get edit => '编辑';

  @override
  String get create => '创建';

  @override
  String get settings => '设置';

  @override
  String get manageTags => '管理标签';

  @override
  String get databaseManager => '数据库管理';

  @override
  String get importExport => '导入 / 导出';

  @override
  String get appearance => '外观';

  @override
  String get darkMode => '深色模式';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get useSystemTheme => '跟随系统';

  @override
  String get language => '语言';

  @override
  String get systemLanguage => '系统默认';

  @override
  String get cardDensity => '卡片密度';

  @override
  String get compact => '紧凑';

  @override
  String get comfortable => '舒适';

  @override
  String get collapseImages => '折叠图片';

  @override
  String get activeDatabase => '当前数据库';

  @override
  String get availableDatabases => '可用数据库';

  @override
  String get createNewDatabase => '创建新数据库';

  @override
  String get enterDatabaseName => '输入数据库名称';

  @override
  String get switchDbConfirmation => '切换数据库';

  @override
  String switchDbMessage(String name) {
    return '确定要切换到数据库 \"$name\" 吗？';
  }

  @override
  String get deleteDbConfirmation => '删除数据库';

  @override
  String deleteDbMessage(String name) {
    return '确定要删除数据库 \"$name\" 吗？此操作无法撤销。';
  }

  @override
  String get dbCreated => '数据库已创建';

  @override
  String get dbDeleted => '数据库已删除';

  @override
  String dbSwitched(String name) {
    return '已切换到数据库: $name';
  }

  @override
  String get allTags => '所有标签';

  @override
  String get noTags => '暂无标签';

  @override
  String get tagName => '标签名称';

  @override
  String get tagColor => '标签颜色';

  @override
  String get deleteTagMessage => '删除此标签？它将从所有事件中移除。';

  @override
  String get importData => '导入数据';

  @override
  String get exportData => '导出数据';

  @override
  String get exportSuccess => '导出成功';

  @override
  String get importSuccess => '导入成功';

  @override
  String get importError => '导入失败';

  @override
  String get sortNewest => '最新';

  @override
  String get sortOldest => '最旧';

  @override
  String get sortTitleAZ => '标题 (A-Z)';

  @override
  String get sortTitleZA => '标题 (Z-A)';

  @override
  String get sortProgressHigh => '进度 (高-低)';

  @override
  String get sortProgressLow => '进度 (低-高)';

  @override
  String get statusAll => '全部';

  @override
  String get statusNotStarted => '未开始';

  @override
  String get statusInProgress => '进行中';

  @override
  String get statusCompleted => '已完成';

  @override
  String get selected => '已选择';

  @override
  String get deleteSelectedConfirmation => '删除选中项？';

  @override
  String deleteSelectedMessage(int count) {
    return '删除 $count 项？';
  }

  @override
  String get editEvent => '编辑事件';

  @override
  String get newEvent => '新建事件';

  @override
  String get title => '标题';

  @override
  String get description => '描述';

  @override
  String get imageUrl => '图片 URL';

  @override
  String get imageUrlPlaceholder => 'http://... 或 data:image...';

  @override
  String get pickImage => '选择图片';

  @override
  String get saveChanges => '保存更改';

  @override
  String get createEvent => '创建事件';

  @override
  String get noTagsYet => '暂无标签';

  @override
  String tagsSelected(int count) {
    return '已选择 $count 个标签';
  }

  @override
  String get clearAllTags => '清空选中';

  @override
  String get deleteTagConfirmation => '删除标签？';

  @override
  String deleteTagWarning(String tag) {
    return '这将从所有事件中移除 \"$tag\"。';
  }

  @override
  String get eventNotFound => '未找到事件';

  @override
  String get eventDetails => '事件详情';

  @override
  String createdOn(String date) {
    return '创建于 $date';
  }

  @override
  String get steps => '步骤';

  @override
  String get manageSteps => '管理步骤';

  @override
  String get noStepsYet => '暂无步骤。';

  @override
  String get addStep => '添加步骤';

  @override
  String get newStepPlaceholder => '新步骤...';

  @override
  String get editSteps => '编辑步骤';

  @override
  String get archive => '归档';

  @override
  String get sets => '集合';

  @override
  String get addNewStepPlaceholder => '添加新步骤...';

  @override
  String get addToArchivePlaceholder => '添加到归档...';

  @override
  String get addedToSteps => '已添加到步骤';

  @override
  String get saveCurrentStepsAsSet => '保存当前步骤为模板集';

  @override
  String get addAllToSteps => '全部添加到步骤';

  @override
  String addedStepsCount(int count) {
    return '已添加 $count 个步骤';
  }

  @override
  String stepsCount(int count) {
    return '$count 个步骤';
  }

  @override
  String get dbNameHint => '例如：project-x, archive-2023';

  @override
  String get invalidDbName => '无效名称。请使用字母、数字、-、_';

  @override
  String get defaultDbName => '主归档 (默认)';

  @override
  String get currentlyActive => '当前激活';

  @override
  String get inactive => '未激活';

  @override
  String get switchDb => '切换';

  @override
  String switchedToDb(String name) {
    return '已切换到 $name';
  }

  @override
  String deleteDbTitle(String name) {
    return '删除 \"$name\"?';
  }

  @override
  String get deleteDbWarning => '此操作无法撤销。该数据库中的所有数据都将丢失。';

  @override
  String get saveTemplateSet => '保存模板集';

  @override
  String get templateName => '模板名称';

  @override
  String get templateSetSaved => '模板集已保存';

  @override
  String get noEventsFound => '未找到事件';

  @override
  String get sort => '排序';

  @override
  String get welcomeTitle => '欢迎使用 Essenmelia';

  @override
  String get welcomeMessage => '管理事件、追踪步骤、使用标签整理生活。点击 + 按钮开始。';

  @override
  String selectedItemsCount(int count) {
    return '已选 $count 项';
  }

  @override
  String get batchArchive => '批量归档';

  @override
  String get batchAdd => '批量添加';

  @override
  String get saveAsSet => '保存为集合';

  @override
  String movedToArchive(int count) {
    return '已将 $count 项移动到归档';
  }

  @override
  String get noArchiveSteps => '暂无存档步骤';

  @override
  String get noStepSets => '暂无步骤集';

  @override
  String get saveCurrentAsSetHint => '你可以将当前步骤保存为集合，方便以后快速复用';

  @override
  String get setName => '集合名称';

  @override
  String get setSaved => '集合已保存';

  @override
  String get tags => '标签';

  @override
  String get tagsPlaceholder => '输入以搜索或创建...';

  @override
  String createTag(String tag) {
    return '创建 \"$tag\"';
  }

  @override
  String failedToPickImage(String error) {
    return '选择图片失败: $error';
  }

  @override
  String get titleRequired => '标题不能为空';

  @override
  String error(String error) {
    return '错误: $error';
  }

  @override
  String get deleteAllDataTitle => '删除所有数据？';

  @override
  String get deleteAllDataMessage => '此操作无法撤销。';

  @override
  String get deleteAllDataSuccess => '所有数据已删除';

  @override
  String importFailedDetailed(String error) {
    return '导入失败：$error';
  }

  @override
  String exportFailedDetailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get navEvents => '事件';

  @override
  String get navExtensions => '扩展';

  @override
  String get addExtension => '添加扩展';

  @override
  String get importFromLocalFile => '从本地文件导入';

  @override
  String get selectJsonExtension => '选择 .json 或 .dart 扩展包';

  @override
  String get enterUrlOrGithubLink => '输入 URL 或 GitHub 链接';

  @override
  String get downloadAndInstallFromLink => '从链接下载并安装';

  @override
  String get confirmUninstall => '确认卸载';

  @override
  String uninstallExtensionWarning(String name) {
    return '确定要卸载扩展 \"$name\" 吗？所有相关设置将被清除。';
  }

  @override
  String get uninstall => '卸载';

  @override
  String get extensionUninstalled => '扩展已卸载';

  @override
  String get extensionRepository => '扩展仓库';

  @override
  String get browseAndInstallFromGithub => '浏览并从 GitHub 安装';

  @override
  String get noExtensionsInstalled => '暂无已安装的扩展';

  @override
  String get deactivated => '已停用';

  @override
  String get downloadFailedCheckLink => '下载失败，请检查链接';

  @override
  String get manageAndPermissions => '管理与权限';

  @override
  String get exportExtensionPackage => '导出扩展包';

  @override
  String get expandTags => '展开标签';

  @override
  String get noEventSelected => '未选择事件';

  @override
  String get noMatchingEvents => '未找到匹配的事件';

  @override
  String get noEventsYet => '暂无事件';

  @override
  String get createFirstEvent => '点击 + 按钮创建你的第一个事件';

  @override
  String get tryAdjustingFilters => '尝试调整过滤器或搜索词';

  @override
  String get batchEditTags => '批量编辑标签';

  @override
  String batchEditTagsTitle(int count) {
    return '编辑 $count 项的标签';
  }

  @override
  String get font => '字体';

  @override
  String get systemFont => '系统字体';

  @override
  String get builtInFont => '内置字体';

  @override
  String get dataMaintenance => '数据维护';

  @override
  String get filter => '筛选';

  @override
  String get status => '状态';
}
