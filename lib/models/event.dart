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
      'isCompleted': isCompleted,
      'completionRate': completionRate,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'completed': completed,
    };
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
