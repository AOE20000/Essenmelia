import 'dart:math';
import '../../models/event.dart';

class MockDataGenerator {
  static final _random = Random();

  static final List<String> _taskTemplates = [
    '整理工作周报',
    '准备会议演示文稿',
    '购买生活用品',
    '阅读《Flutter进阶指南》',
    '健身：力量训练',
    '给花浇水',
    '回复未读邮件',
    '清理桌面环境',
    '学习 Riverpod 状态管理',
    '更新个人博客内容',
    '洗车',
    '去超市采购',
    '制定下周计划',
    '冥想 15 分钟',
    '练习书法',
    '预约牙医检查',
    '备份家庭照片',
    '修理漏水的水龙头',
    '研究新的烹饪菜谱',
    '整理电子邮箱分类',
    '给远方的朋友打电话',
    '学习基础德语会话',
    '参加社区志愿者活动',
    '检查家庭保险箱',
    '修剪花园草坪',
    '更新简历与作品集',
    '观看一部经典老电影',
    '尝试一次手冲咖啡',
    '整理旧衣物捐赠',
    '制定年度储蓄目标',
    '练习尤克里里',
    '深度清洁厨房抽油烟机',
    '购买一张音乐会门票',
    '研究智能家居自动化方案',
    '给爱车添加玻璃水',
    '整理手机中的冗余应用',
    '给阳台的番茄施肥',
    '学习一项新的手工艺',
    '完成在线课程的最终作业',
    '给父母购买健康补品',
  ];

  static final List<String> _stepTemplates = [
    '列出主要完成项',
    '检查拼写错误',
    '导出 PDF 文件',
    '确认参与人员',
    '准备相关物料',
    '记录关键反馈',
    '清理工作区域',
    '提交最终版本',
    '查阅相关技术文档',
    '对比不同方案的优劣',
    '拍摄现场照片记录',
    '核对账单明细',
    '同步数据到云端',
    '测试极端情况下的表现',
    '征求同事的意见',
    '整理成演示文稿',
    '回复所有相关邮件',
    '清理浏览器的缓存',
    '设置定期自动备份',
    '记录过程中的灵感',
    '标注待解决的问题',
    '优化代码性能',
    '增加单元测试用例',
    '撰写项目总结报告',
    '更新相关的 Wiki 页面',
    '修复 CI/CD 构建失败',
    '重构遗留代码模块',
    '更新依赖库版本',
    '编写 API 接口文档',
    '执行数据库迁移脚本',
  ];

  static final List<String> _descriptionTemplates = [
    '这是为了本周目标而准备的详细事项。',
    '需要关注细节，确保不遗漏关键步骤。',
    '根据上周的反馈进行了调整，重点在于执行效率。',
    '长期跟进项目，需要保持定期的记录。',
    '仅作为临时提醒，完成后可直接归档。',
    '涉及多方协作，请务必在沟通后更新进度。',
    '个人提升计划的一部分，旨在培养更好的习惯。',
    '家庭事务，需要与家人共同协商完成。',
    '学习笔记的整理与总结，方便后续复习。',
    '针对紧急情况的预案，需在 24 小时内完成初稿。',
    '季节性维护任务，确保生活环境整洁。',
    '财务相关的核对工作，请保持严谨的态度。',
    '社交活动的前期准备，包括邀约和选址。',
    '这是从第三方应用导入的同步任务。',
    '健康管理的重要环，请按时执行。',
    '请参考 README.md 文件中的说明进行操作。',
    '待处理的 Issue #42 相关的复现步骤。',
    '临时记录的想法，稍后整理到 Notion。',
  ];

  // --- System Info Mocking ---
  static final List<String> _androidVersions = ['11', '12', '13', '14', '15'];
  static final List<String> _manufacturers = [
    'Google',
    'Samsung',
    'Xiaomi',
    'OnePlus',
    'Sony',
    'Oppo',
    'Vivo'
  ];
  static final List<String> _models = [
    'Pixel 6',
    'Pixel 7 Pro',
    'Galaxy S22',
    'Galaxy S23 Ultra',
    'Mi 12',
    'OnePlus 11',
    'Xperia 1 V',
    'Find X6 Pro',
    'X90 Pro+'
  ];

  static Map<String, dynamic> generateSystemInfo() {
    final androidVer = _androidVersions[_random.nextInt(_androidVersions.length)];
    final manufacturer = _manufacturers[_random.nextInt(_manufacturers.length)];
    final model = _models[_random.nextInt(_models.length)];
    
    // 生成一个看起来像真实的 Android ID
    final androidId = List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();
    
    return {
      'platform': 'Android',
      'version': androidVer,
      'model': model,
      'manufacturer': manufacturer,
      'androidId': androidId,
      'isPhysicalDevice': true,
      'sdkVersion': '3.${19 + _random.nextInt(15)}.${_random.nextInt(5)}', // Mock Flutter Version
      'locale': _random.nextBool() ? 'zh_CN' : 'en_US',
    };
  }

  // --- File Content Mocking ---
  static String generateFileContent(String? extension) {
    final ext = extension?.toLowerCase().replaceAll('.', '') ?? 'txt';
    
    switch (ext) {
      case 'json':
        return '{\n  "id": "${_random.nextInt(1000)}",\n  "name": "Mock File",\n  "created_at": "${DateTime.now().toIso8601String()}",\n  "items": [1, 2, 3]\n}';
      case 'csv':
        return 'id,name,value\n1,Item A,100\n2,Item B,200\n3,Item C,300';
      case 'xml':
        return '<root>\n  <item id="1">Value A</item>\n  <item id="2">Value B</item>\n</root>';
      case 'md':
        return '# Mock Markdown File\n\nThis is a generated file content.\n\n- Item 1\n- Item 2';
      case 'yaml':
      case 'yml':
        return 'name: Mock Config\nversion: 1.0.0\nenvironment: development';
      default:
        return 'This is a mock text file content generated at ${DateTime.now()}.';
    }
  }

  // --- Network Response Mocking ---
  static Map<String, dynamic> generateNetworkResponse(String url, String method) {
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? 'example.com';
    final path = uri?.path ?? '/';

    // 针对常见 API 模式返回更真实的数据
    if (host.contains('github.com') || host.contains('api.github.com')) {
        return {
          'id': _random.nextInt(1000000),
          'name': 'mock-repo',
          'full_name': 'mock-user/mock-repo',
          'private': false,
          'description': 'This is a mock repository description.',
          'stargazers_count': _random.nextInt(5000),
          'watchers_count': _random.nextInt(1000),
          'language': 'Dart',
        };
    }

    if (path.contains('/users') || path.contains('/profile')) {
       return {
         'id': _random.nextInt(1000),
         'username': 'mock_user_${_random.nextInt(999)}',
         'email': 'user${_random.nextInt(999)}@example.com',
         'active': true,
         'last_login': DateTime.now().subtract(Duration(days: _random.nextInt(30))).toIso8601String(),
       };
    }
    
    if (path.contains('/posts') || path.contains('/articles')) {
       return {
         'id': _random.nextInt(1000),
         'title': _taskTemplates[_random.nextInt(_taskTemplates.length)],
         'body': _descriptionTemplates[_random.nextInt(_descriptionTemplates.length)],
         'userId': _random.nextInt(100),
       };
    }

    // Default generic response
    return {
      'status': 'success',
      'message': 'Mock response for $method $path',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': {
        'mock_value': _random.nextInt(100),
        'mock_string': 'random_string_${_random.nextInt(1000)}',
      }
    };
  }

  static final List<String> _tags = [
    '工作', '生活', '学习', '健康', '紧急', '个人', '家庭', '社交', '财务', '娱乐', '技能', '待办'
  ];
  static final List<String> _suffixes = ['步骤', '个任务', '项检查', '次练习'];
  static final List<String> _displayModes = ['number', 'firstChar'];

  /// 生成混淆后的模拟数据
  /// [realData] 允许混入一定比例的真实数据（如果提供了）
  static List<Event> generateEvents({
    int count = 15,
    List<Event>? realData,
    bool mixReal = true,
  }) {
    final List<Event> result = [];
    final now = DateTime.now();

    // 1. 如果有真实数据且允许混合，先抽取一部分并进行“脱敏/模糊化”
    // 提高真实数据混合比例到 40% 且上限提高，增加欺骗性
    if (mixReal && realData != null && realData.isNotEmpty) {
      final takeCount = (count * 0.4).round().clamp(1, realData.length);
      final sampled = (List<Event>.from(realData)..shuffle()).take(takeCount);

      for (var real in sampled) {
        result.add(_obfuscateRealEvent(real));
      }
    }

    // 2. 补充基于模板的假数据
    while (result.length < count) {
      result.add(_generateFakeEvent(now));
    }

    // 3. 随机打乱顺序，增加判断难度
    return result..shuffle();
  }

  /// 对真实数据进行混淆处理：修改 ID、微调时间、修改标题关键词
  static Event _obfuscateRealEvent(Event real) {
    final obfuscated = Event();
    // 保持大致的标题意图，但修改关键词，增加模糊性
    String title = real.title;
    final replacements = {
      '项目': '任务',
      '会议': '讨论',
      '计划': '安排',
      '准备': '处理',
      '购买': '获取',
      '学习': '研究',
      '工作': '事项',
    };
    replacements.forEach((old, newVal) {
      title = title.replaceAll(old, newVal);
    });
    obfuscated.title = title;

    if (real.description != null) {
      // 混淆描述：保留原长度感，但内容随机化，或混入模板
      if (_random.nextBool()) {
        obfuscated.description = _descriptionTemplates[_random.nextInt(_descriptionTemplates.length)];
      } else {
        obfuscated.description = '（受限访问）已模糊处理的任务详情，原长度约为 ${real.description!.length} 个字符。';
      }
    }

    // 时间偏移：随机偏移 +/- 4小时内，范围更大
    final offset = Duration(minutes: _random.nextInt(480) - 240);
    obfuscated.createdAt = real.createdAt.add(offset);

    // 标签混淆：保留一部分，随机加一部分
    final tags = (real.tags ?? []).take(1).toList();
    if (tags.length < 2) tags.add(_tags[_random.nextInt(_tags.length)]);
    obfuscated.tags = tags;

    // 自定义显示混淆：大部分保持原样，增加真实感
    obfuscated.stepDisplayMode = real.stepDisplayMode;
    obfuscated.stepSuffix = real.stepSuffix;

    // 提醒时间混淆
    if (real.reminderTime != null) {
      obfuscated.reminderTime = real.reminderTime!.add(offset);
      obfuscated.reminderId = _random.nextInt(100000);
      obfuscated.reminderScheme = real.reminderScheme;
    }

    // 步骤混淆
    obfuscated.steps = real.steps.map((s) {
      final step = EventStep();
      step.description = s.description.length > 5
          ? '${s.description.substring(0, 5)}...'
          : s.description;
      step.completed = s.completed;
      step.timestamp = s.timestamp.add(offset);
      return step;
    }).toList();

    return obfuscated;
  }

  static Event _generateFakeEvent(DateTime referenceTime) {
    final event = Event();
    event.title = _taskTemplates[_random.nextInt(_taskTemplates.length)];

    // 随机 70% 概率生成简介
    if (_random.nextDouble() < 0.7) {
      event.description = _descriptionTemplates[_random.nextInt(_descriptionTemplates.length)];
    }

    // 随机时间分布：过去 7 天内
    final daysOffset = _random.nextInt(7);
    final hoursOffset = _random.nextInt(24);
    event.createdAt = referenceTime.subtract(
      Duration(days: daysOffset, hours: hoursOffset),
    );

    event.tags = [
      _tags[_random.nextInt(_tags.length)],
      if (_random.nextBool()) _tags[_random.nextInt(_tags.length)],
    ];

    // 随机设置自定义显示
    if (_random.nextBool()) {
      event.stepDisplayMode =
          _displayModes[_random.nextInt(_displayModes.length)];
    }
    if (_random.nextBool()) {
      event.stepSuffix = _suffixes[_random.nextInt(_suffixes.length)];
    }

    // 随机 30% 概率生成提醒
    if (_random.nextDouble() < 0.3) {
      event.reminderTime = event.createdAt.add(Duration(days: 1, hours: 2));
      event.reminderId = _random.nextInt(100000);
      event.reminderScheme = _random.nextBool() ? 'notification' : 'calendar';
    }

    // 随机生成 2-5 个步骤
    final stepCount = _random.nextInt(4) + 2;
    event.steps = List.generate(stepCount, (i) {
      final step = EventStep();
      step.description = _stepTemplates[_random.nextInt(_stepTemplates.length)];
      step.completed = _random.nextBool();
      step.timestamp = event.createdAt.add(Duration(minutes: (i + 1) * 30));
      return step;
    });

    return event;
  }
}
