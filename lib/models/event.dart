import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'event.g.dart';

@HiveType(typeId: 0)
class Event extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  late DateTime createdAt;

  @HiveField(4)
  String? imageUrl;

  @HiveField(5)
  List<String>? tags;

  @HiveField(6)
  List<EventStep>? _steps;

  List<EventStep> get steps => _steps ?? [];
  set steps(List<EventStep> value) => _steps = value;

  @HiveField(7)
  String? stepDisplayMode; // 'number' or 'firstChar'

  @HiveField(8)
  String? stepSuffix; // e.g., '步骤', '任务'

  @HiveField(9)
  DateTime? reminderTime;

  @HiveField(10)
  int? reminderId;

  @HiveField(11)
  String? reminderRecurrence; // 'none', 'daily', 'weekly', 'monthly', 'yearly', 'custom'

  @HiveField(12)
  String? reminderScheme; // 'notification' or 'calendar'

  @HiveField(13)
  String? calendarEventId;

  @HiveField(14)
  int? reminderRepeatValue;

  @HiveField(15)
  String? reminderRepeatUnit; // 'minute', 'hour', 'day', 'week', 'month', 'year'

  @HiveField(16)
  List<EventReminder>? reminders;

  @HiveField(17)
  bool? isPinned;

  bool get pinned => isPinned ?? false;
  set pinned(bool value) => isPinned = value;

  bool get isCompleted => steps.isNotEmpty && steps.every((s) => s.completed);

  double get completionRate => steps.isEmpty
      ? 0.0
      : steps.where((s) => s.completed).length / steps.length;

  Event() {
    id = const Uuid().v4();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'imageUrl': imageUrl,
      'tags': tags,
      'steps': steps.map((s) => s.toJson()).toList(),
      'stepDisplayMode': stepDisplayMode,
      'stepSuffix': stepSuffix,
      'reminderTime': reminderTime?.toIso8601String(),
      'reminderId': reminderId,
      'reminderRecurrence': reminderRecurrence,
      'reminderScheme': reminderScheme,
      'calendarEventId': calendarEventId,
      'reminderRepeatValue': reminderRepeatValue,
      'reminderRepeatUnit': reminderRepeatUnit,
      'reminders': (reminders ?? []).map((r) => r.toJson()).toList(),
      'isPinned': pinned,
      'isCompleted': isCompleted,
      'completionRate': completionRate,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final event = Event()
      ..id = json['id'] ?? const Uuid().v4()
      ..title = json['title'] ?? ''
      ..description = json['description']
      ..createdAt = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now()
      ..imageUrl = json['imageUrl']
      ..tags = (json['tags'] as List?)?.cast<String>()
      ..stepDisplayMode = json['stepDisplayMode']
      ..stepSuffix = json['stepSuffix']
      ..reminderTime = json['reminderTime'] != null
          ? DateTime.parse(json['reminderTime'])
          : null
      ..reminderId = json['reminderId']
      ..reminderRecurrence = json['reminderRecurrence']
      ..reminderScheme = json['reminderScheme']
      ..calendarEventId = json['calendarEventId']
      ..reminderRepeatValue = json['reminderRepeatValue']
      ..reminderRepeatUnit = json['reminderRepeatUnit']
      ..isPinned = json['isPinned'] ?? false;

    if (json['steps'] != null) {
      event.steps = (json['steps'] as List)
          .map((s) => EventStep.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    if (json['reminders'] != null) {
      event.reminders = (json['reminders'] as List)
          .map((r) => EventReminder.fromJson(r as Map<String, dynamic>))
          .toList();
    }
    return event;
  }
}

@HiveType(typeId: 10)
class EventReminder extends HiveObject {
  @HiveField(0)
  DateTime? _time;

  DateTime get time => _time ?? DateTime.now();
  set time(DateTime value) => _time = value;

  @HiveField(1)
  int? _id;

  int get id => _id ?? 0;
  set id(int value) => _id = value;

  @HiveField(2)
  String? _recurrence;

  String get recurrence => _recurrence ?? 'none';
  set recurrence(String value) => _recurrence = value;

  @HiveField(3)
  String? _scheme;

  String get scheme => _scheme ?? 'notification';
  set scheme(String value) => _scheme = value;

  @HiveField(4)
  int? repeatValue;

  @HiveField(5)
  String? repeatUnit; // 'minute', 'hour', 'day', 'week', 'month', 'year'

  @HiveField(6)
  int? totalCycles; // 周期数

  @HiveField(7)
  int? currentCycle = 0;

  @HiveField(8)
  String? calendarEventId;

  EventReminder() {
    _id = DateTime.now().millisecondsSinceEpoch.toInt() % 1000000;
    _time = DateTime.now();
    _recurrence = 'none';
    _scheme = 'notification';
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time.toIso8601String(),
      'id': id,
      'recurrence': recurrence,
      'scheme': scheme,
      'repeatValue': repeatValue,
      'repeatUnit': repeatUnit,
      'totalCycles': totalCycles,
      'currentCycle': currentCycle,
      'calendarEventId': calendarEventId,
    };
  }

  factory EventReminder.fromJson(Map<String, dynamic> json) {
    return EventReminder()
      ..time = DateTime.parse(json['time'])
      ..id = json['id']
      ..recurrence = json['recurrence'] ?? 'none'
      ..scheme = json['scheme'] ?? 'notification'
      ..repeatValue = json['repeatValue']
      ..repeatUnit = json['repeatUnit']
      ..totalCycles = json['totalCycles']
      ..currentCycle = json['currentCycle'] ?? 0
      ..calendarEventId = json['calendarEventId'];
  }
}

@HiveType(typeId: 1)
class EventStep extends HiveObject {
  @HiveField(0)
  late String description;

  @HiveField(1)
  late DateTime timestamp;

  @HiveField(2)
  bool? _completed;

  bool get completed => _completed ?? false;
  set completed(bool value) => _completed = value;

  EventStep();

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'completed': completed,
    };
  }

  factory EventStep.fromJson(Map<String, dynamic> json) {
    final step = EventStep()
      ..description = json['description'] ?? ''
      ..timestamp = json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now()
      ..completed = json['completed'] ?? false;
    return step;
  }

  EventStep copyWith({
    String? description,
    DateTime? timestamp,
    bool? completed,
  }) {
    final step = EventStep();
    step.description = description ?? this.description;
    step.timestamp = timestamp ?? this.timestamp;
    step.completed = completed ?? this.completed;
    return step;
  }
}

@HiveType(typeId: 2)
class StepTemplate extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String description;

  @HiveField(2)
  int? _order;

  int get order => _order ?? 0;
  set order(int value) => _order = value;

  StepTemplate() {
    id = const Uuid().v4();
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'description': description, 'order': order};
  }

  factory StepTemplate.fromJson(Map<String, dynamic> json) {
    return StepTemplate()
      ..id = json['id'] ?? const Uuid().v4()
      ..description = json['description'] ?? ''
      ..order = json['order'] ?? 0;
  }
}

@HiveType(typeId: 3)
class StepSetTemplate extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  List<StepSetTemplateStep>? _steps;

  List<StepSetTemplateStep> get steps => _steps ?? [];
  set steps(List<StepSetTemplateStep> value) => _steps = value;

  StepSetTemplate() {
    id = const Uuid().v4();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'steps': steps.map((s) => s.toJson()).toList(),
    };
  }

  factory StepSetTemplate.fromJson(Map<String, dynamic> json) {
    final template = StepSetTemplate()
      ..id = json['id'] ?? const Uuid().v4()
      ..name = json['name'] ?? '';

    if (json['steps'] != null) {
      template.steps = (json['steps'] as List)
          .map((s) => StepSetTemplateStep.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    return template;
  }
}

@HiveType(typeId: 4)
class StepSetTemplateStep extends HiveObject {
  @HiveField(0)
  late String description;

  @HiveField(1)
  int? _order;

  int get order => _order ?? 0;
  set order(int value) => _order = value;

  StepSetTemplateStep();

  Map<String, dynamic> toJson() {
    return {'description': description, 'order': order};
  }

  factory StepSetTemplateStep.fromJson(Map<String, dynamic> json) {
    return StepSetTemplateStep()
      ..description = json['description'] ?? ''
      ..order = json['order'] ?? 0;
  }
}
