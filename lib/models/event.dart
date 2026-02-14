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
  List<EventStep> steps = [];

  @HiveField(7)
  String? stepDisplayMode; // 'number' or 'firstChar'

  @HiveField(8)
  String? stepSuffix; // e.g., '步骤', '任务'

  @HiveField(9)
  DateTime? reminderTime;

  @HiveField(10)
  int? reminderId;

  @HiveField(11)
  String? reminderRecurrence; // 'none', 'daily', 'weekly', 'monthly'

  @HiveField(12)
  String? reminderScheme; // 'notification' or 'calendar'

  @HiveField(13)
  String? calendarEventId;

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
      ..calendarEventId = json['calendarEventId'];

    if (json['steps'] != null) {
      event.steps = (json['steps'] as List)
          .map((s) => EventStep.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    return event;
  }
}

@HiveType(typeId: 1)
class EventStep extends HiveObject {
  @HiveField(0)
  late String description;

  @HiveField(1)
  late DateTime timestamp;

  @HiveField(2)
  bool completed = false;

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
}

@HiveType(typeId: 3)
class StepSetTemplate extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  List<StepSetTemplateStep> steps = [];

  StepSetTemplate() {
    id = const Uuid().v4();
  }
}

@HiveType(typeId: 4)
class StepSetTemplateStep extends HiveObject {
  @HiveField(0)
  late String description;
}
