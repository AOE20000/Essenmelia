import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/event.dart';
import 'db_provider.dart';

class EventsNotifier extends StateNotifier<AsyncValue<List<Event>>> {
  final Ref ref;
  Box<Event>? _box;

  EventsNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      await ref.read(dbProvider.future);
      final activePrefix = ref.read(activePrefixProvider);
      _box = Hive.box<Event>('${activePrefix}_events');

      // Initial load
      state = AsyncValue.data(_box!.values.toList());

      // Watch for changes
      _box!.listenable().addListener(() {
        if (mounted) {
          state = AsyncValue.data(_box!.values.toList());
        }
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addEvent({
    required String title,
    String? description,
    List<String>? tags,
    String? imageUrl,
  }) async {
    if (_box == null) await _init();
    final event = Event()
      ..title = title
      ..description = description
      ..createdAt = DateTime.now()
      ..tags = tags
      ..imageUrl = imageUrl;

    await _box!.put(event.id, event);
  }

  Future<void> deleteEvent(String id) async {
    if (_box == null) await _init();
    await _box!.delete(id);
  }

  Future<void> addStep(String eventId, String description) async {
    if (_box == null) await _init();
    final event = _box!.get(eventId);
    if (event != null) {
      final step = EventStep()
        ..description = description
        ..timestamp = DateTime.now();

      event.steps = [...event.steps, step];
      await event.save();
    }
  }

  Future<void> toggleStep(String eventId, int stepIndex) async {
    if (_box == null) await _init();
    final event = _box!.get(eventId);
    if (event != null && stepIndex < event.steps.length) {
      final steps = List<EventStep>.from(event.steps);
      steps[stepIndex].completed = !steps[stepIndex].completed;
      event.steps = steps;
      await event.save();
    }
  }

  Future<void> updateSteps(String eventId, List<EventStep> newSteps) async {
    if (_box == null) await _init();
    final event = _box!.get(eventId);
    if (event != null) {
      event.steps = newSteps;
      await event.save();
    }
  }

  Future<void> updateTags(String eventId, List<String> tags) async {
    if (_box == null) await _init();
    final event = _box!.get(eventId);
    if (event != null) {
      event.tags = tags;
      await event.save();
    }
  }
}

final eventsProvider =
    StateNotifierProvider<EventsNotifier, AsyncValue<List<Event>>>((ref) {
      return EventsNotifier(ref);
    });

// Templates Providers

final templatesProvider = StreamProvider<List<StepTemplate>>((ref) async* {
  await ref.watch(dbProvider.future);
  final activePrefix = ref.read(activePrefixProvider);
  final box = Hive.box<StepTemplate>('${activePrefix}_templates');
  yield box.values.toList();
  yield* box.watch().map((event) => box.values.toList());
});

final stepSetTemplatesProvider = StreamProvider<List<StepSetTemplate>>((
  ref,
) async* {
  await ref.watch(dbProvider.future);
  final activePrefix = ref.read(activePrefixProvider);
  final box = Hive.box<StepSetTemplate>('${activePrefix}_set_templates');
  yield box.values.toList();
  yield* box.watch().map((event) => box.values.toList());
});

class TemplatesController {
  final Ref ref;
  TemplatesController(this.ref);

  Future<void> addTemplate(String description) async {
    await ref.read(dbProvider.future);
    final activePrefix = ref.read(activePrefixProvider);
    final box = Hive.box<StepTemplate>('${activePrefix}_templates');
    final template = StepTemplate()..description = description;
    await box.put(template.id, template);
  }

  Future<void> deleteTemplate(String id) async {
    await ref.read(dbProvider.future);
    final activePrefix = ref.read(activePrefixProvider);
    final box = Hive.box<StepTemplate>('${activePrefix}_templates');
    await box.delete(id);
  }
}

class SetTemplatesController {
  final Ref ref;
  SetTemplatesController(this.ref);

  Future<void> addSetTemplate(String name, List<String> steps) async {
    await ref.read(dbProvider.future);
    final activePrefix = ref.read(activePrefixProvider);
    final box = Hive.box<StepSetTemplate>('${activePrefix}_set_templates');
    final template = StepSetTemplate()
      ..name = name
      ..steps = steps
          .map((s) => StepSetTemplateStep()..description = s)
          .toList();
    await box.put(template.id, template);
  }

  Future<void> deleteSetTemplate(String id) async {
    await ref.read(dbProvider.future);
    final activePrefix = ref.read(activePrefixProvider);
    final box = Hive.box<StepSetTemplate>('${activePrefix}_set_templates');
    await box.delete(id);
  }
}

final templatesControllerProvider = Provider((ref) => TemplatesController(ref));
final setTemplatesControllerProvider = Provider(
  (ref) => SetTemplatesController(ref),
);
