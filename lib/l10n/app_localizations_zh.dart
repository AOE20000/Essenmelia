// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get uninstallExtension => '卸载扩展';

  @override
  String uninstallConfirmation(String name) {
    return '确定要卸载“$name”吗？';
  }

  @override
  String pasteFailed(String error) {
    return '粘贴失败：$error';
  }

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get appTitle => 'Essenmelia';

  @override
  String get searchPlaceholder => '搜索事件...';

  @override
  String get select => '选择';

  @override
  String get cancel => '取消';

  @override
  String get newTag => '新标签';

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
  String get createRecord => '创建记录';

  @override
  String get settings => '设置';

  @override
  String get manageTags => '标签管理';

  @override
  String get databaseManager => '数据库管理';

  @override
  String get loading => '加载中...';

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
  String get english => 'English';

  @override
  String get chinese => '中文';

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
    return '确定要删除数据库 \"$name\" 吗？此操作不可撤销。';
  }

  @override
  String get dbCreated => '数据库已创建';

  @override
  String get dbDeleted => '数据库已删除';

  @override
  String dbSwitched(String name) {
    return '已切换到数据库：$name';
  }

  @override
  String get allTags => '所有标签';

  @override
  String get recommendedTags => '推荐标签';

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
  String get sortNewest => '最新优先';

  @override
  String get sortTime => '时间';

  @override
  String get sortOldest => '最早优先';

  @override
  String get sortTitleAZ => '标题 (A-Z)';

  @override
  String get sortTitle => '标题';

  @override
  String get sortTitleZA => '标题 (Z-A)';

  @override
  String get sortProgressHigh => '进度 (高-低)';

  @override
  String get sortProgress => '进度';

  @override
  String get sortProgressLow => '进度 (低-高)';

  @override
  String get sortStepCountHigh => '步骤 (多-少)';

  @override
  String get sortSteps => '步骤';

  @override
  String get sortStepCountLow => '步骤 (少-多)';

  @override
  String get sortTagCountHigh => '标签 (多-少)';

  @override
  String get sortTags => '标签';

  @override
  String get sortTagCountLow => '标签 (少-多)';

  @override
  String get sortLastUpdated => '最近更新';

  @override
  String get sortUpdated => '更新';

  @override
  String get sortLastUpdatedOldest => '最早更新';

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
  String get deleteSelectedConfirmation => '删除所选？';

  @override
  String deleteSelectedMessage(int count) {
    return '确认删除这 $count 个项目？';
  }

  @override
  String get editEvent => '编辑事件';

  @override
  String get newEvent => '新事件';

  @override
  String get title => '标题';

  @override
  String get description => '描述';

  @override
  String get imageUrl => '图片链接';

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
    return '已选 $count 个标签';
  }

  @override
  String get clearAllTags => '清空选择';

  @override
  String get deleteTagConfirmation => '删除标签？';

  @override
  String deleteTagWarning(String tag) {
    return '这将从所有事件中移除标签 \"$tag\"。';
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
  String get addNewStepPlaceholder => '添加新步骤...';

  @override
  String get addedToSteps => '已添加到步骤';

  @override
  String get newStepPlaceholder => '新步骤...';

  @override
  String get editSteps => '编辑步骤';

  @override
  String get extensions => '扩展';

  @override
  String get extensionDetails => '扩展详情';

  @override
  String get extensionOpen => '打开扩展';

  @override
  String get extensionLinkSubtitle => '支持 URL 或 GitHub 链接';

  @override
  String get installFromClipboard => '从剪贴板安装链接';

  @override
  String get installFromClipboardSubtitle => '支持 ZIP / GitHub 链接';

  @override
  String get invalidInput => '输入无效';

  @override
  String resetFailedDetailed(String error) {
    return '重置失败: $error';
  }

  @override
  String dbStats(int events, int templates) {
    return '$events 个事件, $templates 个模板';
  }

  @override
  String get noAvailableExtensions => '商店中暂无可用扩展';

  @override
  String get failedToLoadStore => '无法加载商店';

  @override
  String get extensionPureMode => '扩展信息';

  @override
  String extensionStorageOccupied(String size) {
    return '存储占用: $size';
  }

  @override
  String get extensionDeveloperSandbox => '开发沙箱';

  @override
  String get extensionSandboxInstruction =>
      '此扩展目前作为“纯净壳”运行。你可以点击下方按钮测试其申请的权限是否生效。';

  @override
  String get extensionGetEvents => '获取事件';

  @override
  String get extensionSendNotification => '发送通知';

  @override
  String extensionGetEventsSuccess(int count) {
    return '成功获取 $count 个事件';
  }

  @override
  String extensionGetEventsFailed(String error) {
    return '获取失败: $error';
  }

  @override
  String get extensionSandboxNotification => '来自扩展沙箱的测试通知';

  @override
  String get extensionDefaultButtonLabel => '按钮';

  @override
  String get retry => '重试';

  @override
  String get useCustomStoreLink => '使用自定义商店链接';

  @override
  String get customStore => '自定义商店';

  @override
  String get load => '加载';

  @override
  String authorLabel(String author) {
    return '作者: $author';
  }

  @override
  String versionAuthorLabel(String version, String author) {
    return '版本 $version • 作者 $author';
  }

  @override
  String get aboutExtension => '关于此扩展';

  @override
  String get installExtension => '安装扩展';

  @override
  String installingExtension(String name) {
    return '正在下载并安装 $name...';
  }

  @override
  String installSuccess(String name) {
    return '$name 安装成功';
  }

  @override
  String get installFailed => '安装失败，请检查链接或网络';

  @override
  String installError(String error) {
    return '安装出错: $error';
  }

  @override
  String get eventReminder => '事件提醒';

  @override
  String get eventReminderChannelDesc => '用于事件的定时提醒';

  @override
  String get systemNotification => '系统通知';

  @override
  String get systemNotificationChannelDesc => '来自应用或扩展的即时通知';

  @override
  String get extensionCategoryNotifications => '系统通知';

  @override
  String get extensionUninstall => '卸载';

  @override
  String get extensionUninstallConfirm => '确认卸载';

  @override
  String extensionUninstallMessage(String name) {
    return '确定要卸载扩展 \"$name\" 吗？此操作将删除其所有关联数据且不可撤销。';
  }

  @override
  String get extensionExport => '导出扩展';

  @override
  String get extensionCopyGitHubLink => '复制 GitHub 链接';

  @override
  String get extensionCopyGitHubLinkSubtitle => '便于在其他设备分享';

  @override
  String get extensionExportZip => '导出 ZIP 源码包';

  @override
  String get extensionExportZipSubtitle => '包含完整扩展源码的压缩包';

  @override
  String get manualImport => '手动导入';

  @override
  String get manualImportTitle => '手动导入扩展';

  @override
  String get manualImportUrlHint => '输入 GitHub 仓库 URL 或 ZIP 链接';

  @override
  String get manualImportDescription => '支持从 GitHub 仓库、Raw 链接或直接 ZIP 下载地址导入。';

  @override
  String get import => '导入';

  @override
  String get extensionPermissionReadEvents => '读取事件';

  @override
  String get extensionPermissionReadEventsDesc => '允许扩展查看您的所有事件和任务。';

  @override
  String get extensionPermissionAddEvents => '添加事件';

  @override
  String get extensionPermissionAddEventsDesc => '允许扩展创建新任务。';

  @override
  String get extensionPermissionUpdateEvents => '更新事件';

  @override
  String get extensionPermissionUpdateEventsDesc => '允许扩展修改现有任务。';

  @override
  String get extensionPermissionDeleteEvents => '删除事件';

  @override
  String get extensionPermissionDeleteEventsDesc => '允许扩展删除您的任务。';

  @override
  String get extensionPermissionReadTags => '读取标签';

  @override
  String get extensionPermissionReadTagsDesc => '允许扩展查看您的标签列表。';

  @override
  String get extensionPermissionManageTags => '管理标签';

  @override
  String get extensionPermissionManageTagsDesc => '允许扩展添加或删除全局标签。';

  @override
  String get extensionPermissionManageDb => '管理数据库';

  @override
  String get extensionPermissionManageDbDesc => '允许扩展执行数据库导出、备份或切换操作。';

  @override
  String get extensionPermissionFileSystem => '文件系统';

  @override
  String get extensionPermissionFileSystemDesc => '允许扩展将文件保存到您的设备或读取文件。';

  @override
  String get extensionPermissionNotifications => '通知权限';

  @override
  String get extensionPermissionNotificationsDesc => '允许扩展向您发送桌面或系统通知。';

  @override
  String get extensionPermissionReadCalendar => '读取日历';

  @override
  String get extensionPermissionReadCalendarDesc => '允许扩展读取您的系统日历事件。';

  @override
  String get extensionPermissionWriteCalendar => '写入日历';

  @override
  String get extensionPermissionWriteCalendarDesc => '允许扩展在您的系统日历中添加或修改事件。';

  @override
  String get extensionPermissionNetwork => '网络访问';

  @override
  String get extensionPermissionNetworkDesc => '允许扩展访问互联网。';

  @override
  String get extensionPermissionSystemInfo => '系统信息';

  @override
  String get extensionPermissionSystemInfoDesc => '允许扩展访问系统状态，如主题、语言和消息提示。';

  @override
  String get extensionPermissionNavigation => '界面导航';

  @override
  String get extensionPermissionNavigationDesc => '允许扩展跳转到特定页面或过滤搜索结果。';

  @override
  String get extensionPermissionUIInteraction => '界面交互';

  @override
  String get extensionPermissionUIInteractionDesc => '允许扩展显示对话框、提示条或自定义界面元素。';

  @override
  String get extensionCategoryDataReading => '数据读取';

  @override
  String get extensionCategoryDataWriting => '数据写入';

  @override
  String get extensionCategoryFileSystem => '文件系统';

  @override
  String get extensionCategoryNetwork => '网络访问';

  @override
  String get extensionCategorySystemInfo => '系统信息';

  @override
  String get extensionCategoryNavigation => '界面导航';

  @override
  String get extensionCategoryUIInteraction => '界面交互';

  @override
  String get extensionCategoryGeneral => '常规权限';

  @override
  String get extensionManagementTitle => '扩展程序';

  @override
  String get extensionSectionInstalled => '已安装';

  @override
  String get extensionSectionBuiltIn => '内置';

  @override
  String get extensionSectionOnline => 'GITHUB_ESSENMELIA_EXTEND';

  @override
  String updateAvailable(String version) {
    return '发现新版本 v$version';
  }

  @override
  String get extensionRestrictedAccess => '受限访问';

  @override
  String get extensionRestrictedAccessDesc => '所有数据访问均需手动授权。';

  @override
  String get extensionInterceptedTitle => '访问被拦截';

  @override
  String extensionInterceptedDesc(String name, String action) {
    return '扩展 $name $action：';
  }

  @override
  String get extensionInterceptedActionTried => '刚才尝试进行';

  @override
  String get extensionInterceptedActionWants => '想要进行';

  @override
  String get extensionDecisionDeny => '拒绝访问';

  @override
  String get extensionDecisionDenyDesc => '不提供数据，可能会导致扩展运行错误或功能受限。';

  @override
  String get extensionDecisionOnce => '允许本次';

  @override
  String get extensionDecisionOnceDesc => '仅为本次特定请求提供真实数据。';

  @override
  String get extensionDecisionNext => '下次允许';

  @override
  String get extensionDecisionNextDesc => '本次拦截，但下次发生同类访问时自动允许。';

  @override
  String get extensionDecisionSessionCategory => '允许此类 (本会话)';

  @override
  String get extensionDecisionSessionCategoryDesc => '在应用关闭前，允许此类别的所有访问。';

  @override
  String get extensionDecisionSessionAll => '允许全部 (本会话)';

  @override
  String get extensionDecisionSessionAllDesc => '在应用关闭前，允许此扩展的所有权限申请。';

  @override
  String get archive => '存档';

  @override
  String get sets => '模板集';

  @override
  String get addToArchivePlaceholder => '添加到存档...';

  @override
  String get extensionLogsTitle => '系统扩展日志';

  @override
  String get noApiLogs => '暂无 API 调用记录';

  @override
  String get noParams => '无参数';

  @override
  String get restrictedAccess => '受限访问';

  @override
  String get logDetails => '调用详情';

  @override
  String get extensionNameLabel => '扩展名称';

  @override
  String get extensionIdLabel => '扩展 ID';

  @override
  String get methodLabel => '调用方法';

  @override
  String get timeLabel => '调用时间';

  @override
  String get statusLabel => '状态';

  @override
  String get successLabel => '成功';

  @override
  String get failedLabel => '失败';

  @override
  String get accessModeLabel => '访问模式';

  @override
  String get restrictedAccessIntercepted => '受限访问 (拦截)';

  @override
  String get trustedModePassthrough => '信任模式 (直通)';

  @override
  String get errorMessageLabel => '错误信息';

  @override
  String get paramsDetails => '参数详情';

  @override
  String get saveCurrentStepsAsSet => '将当前步骤保存为模板集';

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
  String get dbNameHint => '例如：项目-X, 2023存档';

  @override
  String get invalidDbName => '名称无效。请使用字母、数字、-、_';

  @override
  String get defaultDbName => '主存档 (默认)';

  @override
  String get currentlyActive => '当前活动';

  @override
  String get inactive => '未启用';

  @override
  String get switchDb => '切换';

  @override
  String switchedToDb(String name) {
    return '已切换到 $name';
  }

  @override
  String deleteDbTitle(String name) {
    return '删除 \"$name\"？';
  }

  @override
  String get deleteDbWarning => '此操作不可撤销。该数据库中的所有数据都将丢失。';

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
  String get welcomeMessage => '管理您的事件，追踪步骤，并使用标签组织生活。点击 + 按钮开始使用。';

  @override
  String selectedItemsCount(int count) {
    return '已选择 $count 个项目';
  }

  @override
  String get batchArchive => '批量存档';

  @override
  String get batchAdd => '批量添加';

  @override
  String get saveAsSet => '另存为模板集';

  @override
  String movedToArchive(int count) {
    return '已将 $count 个项目移至存档';
  }

  @override
  String get noArchiveSteps => '暂无存档步骤';

  @override
  String get noStepSets => '暂无模板集';

  @override
  String get saveCurrentAsSetHint => '您可以将当前步骤保存为模板集，以便日后快速复用';

  @override
  String get setName => '模板集名称';

  @override
  String get setSaved => '组合已保存';

  @override
  String get tags => '标签';

  @override
  String get noEventsWithTag => '没有带有此标签的事件';

  @override
  String get allEvents => '所有事件';

  @override
  String get tagsPlaceholder => '输入以搜索或创建...';

  @override
  String createTag(String tag) {
    return '创建 \"$tag\"';
  }

  @override
  String failedToPickImage(String error) {
    return '选择图片失败：$error';
  }

  @override
  String get titleRequired => '标题不能为空';

  @override
  String error(String error) {
    return '错误：$error';
  }

  @override
  String get deleteAllDataTitle => '删除所有数据？';

  @override
  String get deleteAllDataMessage => '此操作不可撤销。';

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
  String get selectJsonExtension => '选择 .zip 扩展包';

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
  String extensionUninstalled(String name) {
    return '扩展“$name”已卸载';
  }

  @override
  String get extensionRepository => '扩展仓库';

  @override
  String get browseAndInstallFromGithub => '从 GitHub 浏览并安装';

  @override
  String get noExtensionsInstalled => '未安装扩展';

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
  String get noMatchingEvents => '未找到匹配事件';

  @override
  String get noEventsYet => '暂无事件';

  @override
  String get createFirstEvent => '点击 + 按钮创建您的第一个事件';

  @override
  String get tryAdjustingFilters => '尝试调整过滤器或搜索词';

  @override
  String get batchEditTags => '批量编辑标签';

  @override
  String batchEditTagsTitle(int count) {
    return '编辑 $count 个项目的标签';
  }

  @override
  String get addTags => '添加标签';

  @override
  String get removeTags => '移除标签';

  @override
  String tagsUpdated(int count) {
    return '已更新 $count 个项目的标签';
  }

  @override
  String get noTagsSelected => '未选择标签';

  @override
  String get apply => '应用';

  @override
  String get help => '帮助';

  @override
  String get welcome => '欢迎';

  @override
  String get welcomeAndHelp => '欢迎与帮助';

  @override
  String get helpTitle => '帮助中心';

  @override
  String get helpMessage => '在此学习如何使用 Essenmelia。管理您的事件、步骤和扩展。';

  @override
  String get backToWelcome => '返回欢迎页';

  @override
  String get switchToHelp => '查看帮助';

  @override
  String get getStarted => '开始使用';

  @override
  String get font => '字体';

  @override
  String get systemFont => '系统默认';

  @override
  String get builtInFont => 'Google Fonts (Roboto)';

  @override
  String get fontDownloadTitle => '下载字体？';

  @override
  String get fontDownloadContent => '这将使用 Google Fonts，需要连接互联网下载字体资源。是否继续？';

  @override
  String lastSync(String time) {
    return '上次同步: $time';
  }

  @override
  String get dataMaintenance => '数据维护';

  @override
  String get dangerZone => '危险区域';

  @override
  String get formatApp => '格式化应用';

  @override
  String get formatAppWarning => '这将物理删除所有数据库，清空所有扩展沙盒，并重置所有应用设置。此操作不可逆！';

  @override
  String get formatAppConfirm => '输入 \'DELETE\' 以确认';

  @override
  String get formatAppPlaceholder => '在此输入 DELETE';

  @override
  String get currentDbActions => '当前数据库操作';

  @override
  String get extensionAllSystemPermissions => '所有系统权限';

  @override
  String get extensionConfirmChoice => '确认选择';

  @override
  String get extensionRuntimeSection => '运行与安全';

  @override
  String get extensionEnable => '启用扩展';

  @override
  String get extensionRunning => '运行中';

  @override
  String get extensionStopped => '已停止';

  @override
  String get extensionSandboxIsolation => '沙盒隔离';

  @override
  String get extensionIsolatedSandbox => '独立沙盒';

  @override
  String extensionSharedSandbox(String id) {
    return '共享沙盒：$id';
  }

  @override
  String get extensionSandboxGroup => '沙盒组';

  @override
  String get extensionSandboxDesc => '沙盒组决定数据隔离。输入相同的 ID 以共享存储。';

  @override
  String get extensionSandboxId => '沙盒 ID';

  @override
  String get extensionSandboxDefaultHint => '默认为扩展 ID';

  @override
  String get extensionSandboxTip => '提示：活跃扩展通常共享同一分组';

  @override
  String get extensionRequestedPermissions => '申请的权限';

  @override
  String get extensionNoPermissions => '未申请权限';

  @override
  String get extensionUpdate => '更新扩展';

  @override
  String get extensionInstall => '安装扩展';

  @override
  String get extensionInformation => '扩展信息';

  @override
  String get extensionVersion => '版本';

  @override
  String get extensionNotInstalled => '未安装';

  @override
  String get extensionCodeSize => '代码大小';

  @override
  String get extensionStorageSize => '占用空间';

  @override
  String get extensionFullTrust => '完全信任';

  @override
  String get extensionFullTrustDesc => '直接访问系统 API';

  @override
  String get extensionPermissionsStatement => '权限声明';

  @override
  String get extensionNoChanges => '无变更';

  @override
  String get extensionNoPermissionsRequired => '无需任何权限';

  @override
  String get update => '更新';

  @override
  String get install => '安装';

  @override
  String databaseError(String error) {
    return '数据库错误: $error';
  }

  @override
  String get filter => '筛选';

  @override
  String get status => '状态';

  @override
  String get extensionRequested => '扩展申请';

  @override
  String get onlyShowReminders => '仅显示提醒';

  @override
  String get onlyShowRemindersSubtitle => '过滤掉没有提醒的任务';

  @override
  String get viewAll => '查看全部';

  @override
  String get extensionLogs => '扩展日志';

  @override
  String get welcomeToExtensions => '欢迎使用扩展系统';

  @override
  String get dontShowAgain => '不再显示';

  @override
  String get longPressToManageExtension => '长按扩展进入管理页面';

  @override
  String get daily => '每天';

  @override
  String get weekly => '每周';

  @override
  String get monthly => '每月';

  @override
  String get recurrenceDaily => ' (每天)';

  @override
  String get recurrenceWeekly => ' (每周)';

  @override
  String get recurrenceMonthly => ' (每月)';

  @override
  String get exploreEssenmelia => '探索 Essenmelia';

  @override
  String get helpAndDocs => '帮助与文档';

  @override
  String get welcomeSubtitle1 => '您的个人日程与灵感管理专家';

  @override
  String get welcomeContent1 => '高效组织生活中的每一个精彩瞬间。无论是琐碎的日常，还是宏大的计划，都能在这里找到归宿。';

  @override
  String get privacyFirst => '隐私优先';

  @override
  String get welcomeSubtitle2 => '安全、透明、可控';

  @override
  String get welcomeContent2 => '所有数据本地存储，非信任插件只能访问由系统生成的伪造数据，确保您的真实信息永不外泄。';

  @override
  String get highlyCustomizable => '高度自定义';

  @override
  String get welcomeSubtitle3 => '随心而动，无限可能';

  @override
  String get welcomeContent3 =>
      '通过强大的插件系统，您可以轻松扩展应用功能。使用声明式 UI 引擎，定制属于您的专属管理工具。';

  @override
  String get startExperience => '开始体验';

  @override
  String get nextStep => '下一步';

  @override
  String get archDesign => '架构设计';

  @override
  String get archDesignDesc => '系统分层、隐私黑盒与权限模型';

  @override
  String get apiGuide => 'API 使用指南';

  @override
  String get apiGuideDesc => '核心方法、通知方案与外部集成';

  @override
  String get extDevSpecs => '扩展开发规范';

  @override
  String get extDevSpecsDesc => '信息、UI 组件库与逻辑引擎';

  @override
  String get createRepoGuide => '扩展仓库创建指南';

  @override
  String get createRepoGuideDesc => '清单文件、结构与 GitHub 发现机制';

  @override
  String get selectDocToRead => '请选择一个文档进行阅读';

  @override
  String loadFailed(String error) {
    return '加载失败: $error';
  }

  @override
  String get advancedSettingsAndReminders => '高级设置与提醒';

  @override
  String get advancedSettingsSubtitle => '显示方式、数量后缀、定时提醒';

  @override
  String get advancedSettings => '高级设置';

  @override
  String get finishSettings => '完成设置';

  @override
  String get displaySettings => '显示设置';

  @override
  String get stepMarkerMode => '步骤标记显示方式';

  @override
  String get markerNumber => '序号 (1, 2, 3)';

  @override
  String get markerFirstChar => '首字 (简, 繁, 拼)';

  @override
  String get customCountSuffix => '自定义数量后缀';

  @override
  String get suffixHint => '例如：任务、步骤、个';

  @override
  String get suffixDefaultTip => '留空则使用默认后缀';

  @override
  String get scheduledReminders => '定时提醒';

  @override
  String get noReminderSet => '未设置提醒';

  @override
  String get calendarReminderDesc => '将注册到系统日历，无需后台运行';

  @override
  String get notificationReminderDesc => '将在指定时间发送通知提醒您';

  @override
  String get reminderScheme => '提醒方案';

  @override
  String get inAppNotification => '应用内通知';

  @override
  String get systemCalendar => '系统日历';

  @override
  String get repeatCycle => '重复周期';

  @override
  String get noRepeat => '不重复';

  @override
  String get reminderTimeError => '提醒时间不能早于当前时间';

  @override
  String get smartAnalysis => '智能分析选择';

  @override
  String get brilliantMoments => '精彩画面';

  @override
  String get aiCrop => 'AI 裁切';

  @override
  String get ocrResults => '识别结果';

  @override
  String get ocrSelectionTip => '点击选择：第一次点击设置为标题，后续点击追加到描述';

  @override
  String get resetOcrSelection => '重置文字选择';

  @override
  String get appPreview => '应用预览';

  @override
  String get confirmApply => '确认应用';

  @override
  String get analyzingContent => '正在分析内容...';

  @override
  String get smartAnalysisTooltip => '智能分析内容';

  @override
  String get autoFilledByAi => 'AI 助手已自动填充';

  @override
  String get unsupportedFileFormat => '不支持的文件格式';

  @override
  String get noImageInClipboard => '剪贴板中未找到图片或有效链接';

  @override
  String failedToGetImageFromLink(String error) {
    return '从链接获取图片失败：$error';
  }

  @override
  String get pickFromGallery => '从相册选择';

  @override
  String get pasteFromClipboard => '从剪贴板粘贴';

  @override
  String get clearImage => '清除图片';

  @override
  String get addStoryImage => '添加一张有故事的图片';

  @override
  String get imageUploadTip => '拖放、粘贴或选择图片';

  @override
  String get exportOriginalImage => '导出原图';

  @override
  String get exportImage => '导出图片';

  @override
  String processingImageFailed(String error) {
    return '处理图片失败：$error';
  }

  @override
  String reminderAt(String time) {
    return '提醒：$time';
  }

  @override
  String get quickEdit => '快速编辑 (长按滑动)';

  @override
  String get extensionConsole => '扩展控制台';

  @override
  String get logs => '日志';

  @override
  String get stateTree => '状态树';

  @override
  String get restartEngine => '重启引擎';

  @override
  String get noLogs => '暂无日志';

  @override
  String get currentStateVariables => '当前状态变量 (State):';

  @override
  String editState(String key) {
    return '编辑状态: $key';
  }

  @override
  String get jsonFormatValue => 'JSON 格式值';

  @override
  String get jsonHint => '例如: \"text\" 或 123 或 JSON 对象';

  @override
  String invalidJson(String error) {
    return '无效的 JSON: $error';
  }

  @override
  String get fullOriginalImage => '完整原图';

  @override
  String get allSystemPermissions => '所有系统权限';

  @override
  String get extensionError => '扩展脚本运行错误';

  @override
  String get extensionNoUI => '此扩展未定义界面。';

  @override
  String get extensionButton => '按钮';
}
