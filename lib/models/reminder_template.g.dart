// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReminderTemplateAdapter extends TypeAdapter<ReminderTemplate> {
  @override
  final int typeId = 20;

  @override
  ReminderTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReminderTemplate()
      ..id = fields[0] as String
      ..name = fields[1] as String
      ..time = fields[2] as DateTime
      ..recurrence = fields[3] as String
      ..scheme = fields[4] as String
      ..repeatValue = fields[5] as int?
      ..repeatUnit = fields[6] as String?
      ..totalCycles = fields[7] as int?;
  }

  @override
  void write(BinaryWriter writer, ReminderTemplate obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.time)
      ..writeByte(3)
      ..write(obj.recurrence)
      ..writeByte(4)
      ..write(obj.scheme)
      ..writeByte(5)
      ..write(obj.repeatValue)
      ..writeByte(6)
      ..write(obj.repeatUnit)
      ..writeByte(7)
      ..write(obj.totalCycles);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
