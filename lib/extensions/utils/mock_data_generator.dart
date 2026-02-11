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
  ];

  static final List<String> _tags = ['工作', '生活', '学习', '健康', '紧急', '个人'];

  /// 生成混淆后的模拟数据
  /// [realCount] 允许混入一定比例的真实数据（如果提供了）
  static List<Event> generateEvents({
    int count = 10,
    List<Event>? realData,
    bool mixReal = false,
  }) {
    final List<Event> result = [];
    final now = DateTime.now();

    // 1. 如果有真实数据且允许混合，先抽取一部分并进行“脱敏/模糊化”
    if (mixReal && realData != null && realData.isNotEmpty) {
      final takeCount = (count * 0.3).round().clamp(1, realData.length);
      final sampled = (realData..shuffle()).take(takeCount);

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
    // 保持大致的标题意图，但修改关键词
    obfuscated.title = real.title.replaceAll('项目', '任务').replaceAll('会议', '讨论');
    obfuscated.description = real.description != null ? '已处理的备注' : null;

    // 时间偏移：随机偏移 +/- 2小时内
    final offset = Duration(minutes: _random.nextInt(240) - 120);
    obfuscated.createdAt = real.createdAt.add(offset);

    // 标签混淆：保留一部分，随机加一部分
    final tags = (real.tags ?? []).take(1).toList();
    if (tags.length < 2) tags.add(_tags[_random.nextInt(_tags.length)]);
    obfuscated.tags = tags;

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
