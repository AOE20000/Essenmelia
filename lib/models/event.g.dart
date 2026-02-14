// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EventAdapter extends TypeAdapter<Event> {
  @override
  final int typeId = 0;

  @override
  Event read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Event()
      ..id = fields[0] as String
      ..title = fields[1] as String
      ..description = fields[2] as String?
      ..createdAt = fields[3] as DateTime
      ..imageUrl = fields[4] as String?
      ..tags = (fields[5] as List?)?.cast<String>()
      ..steps = (fields[6] as List).cast<EventStep>()
      ..stepDisplayMode = fields[7] as String?
      ..stepSuffix = fields[8] as String?
      ..reminderTime = fields[9] as DateTime?
      ..reminderId = fields[10] as int?
      ..reminderRecurrence = fields[11] as String?
      ..reminderScheme = fields[12] as String?
      ..calendarEventId = fields[13] as String?;
  }

  @override
  void write(BinaryWriter writer, Event obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.imageUrl)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.steps)
      ..writeByte(7)
      ..write(obj.stepDisplayMode)
      ..writeByte(8)
      ..write(obj.stepSuffix)
      ..writeByte(9)
      ..write(obj.reminderTime)
      ..writeByte(10)
      ..write(obj.reminderId)
      ..writeByte(11)
      ..write(obj.reminderRecurrence)
      ..writeByte(12)
      ..write(obj.reminderScheme)
      ..writeByte(13)
      ..write(obj.calendarEventId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EventStepAdapter extends TypeAdapter<EventStep> {
  @override
  final int typeId = 1;

  @override
  EventStep read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EventStep()
      ..description = fields[0] as String
      ..timestamp = fields[1] as DateTime
      ..completed = fields[2] as bool;
  }

  @override
  void write(BinaryWriter writer, EventStep obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.description)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.completed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventStepAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StepTemplateAdapter extends TypeAdapter<StepTemplate> {
  @override
  final int typeId = 2;

  @override
  StepTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StepTemplate()
      ..id = fields[0] as String
      ..description = fields[1] as String
      .._order = fields[2] as int?;
  }

  @override
  void write(BinaryWriter writer, StepTemplate obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj._order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StepSetTemplateAdapter extends TypeAdapter<StepSetTemplate> {
  @override
  final int typeId = 3;

  @override
  StepSetTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StepSetTemplate()
      ..id = fields[0] as String
      ..name = fields[1] as String
      ..steps = (fields[2] as List).cast<StepSetTemplateStep>();
  }

  @override
  void write(BinaryWriter writer, StepSetTemplate obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.steps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepSetTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StepSetTemplateStepAdapter extends TypeAdapter<StepSetTemplateStep> {
  @override
  final int typeId = 4;

  @override
  StepSetTemplateStep read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StepSetTemplateStep()..description = fields[0] as String;
  }

  @override
  void write(BinaryWriter writer, StepSetTemplateStep obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepSetTemplateStepAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
