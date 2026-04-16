// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timed_check_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TimedCheckSessionAdapter extends TypeAdapter<TimedCheckSession> {
  @override
  final int typeId = 5;

  @override
  TimedCheckSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimedCheckSession(
      id: fields[0] as String,
      userId: fields[1] as String,
      startTime: fields[2] as DateTime,
      endTime: fields[3] as DateTime,
      durationMinutes: fields[4] as int,
      status: fields[5] as String,
      heartbeatDataIds: (fields[6] as List).cast<String>(),
      aiAnalysis: fields[7] as String?,
      healthCondition: fields[8] as String?,
      createdAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TimedCheckSession obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.durationMinutes)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.heartbeatDataIds)
      ..writeByte(7)
      ..write(obj.aiAnalysis)
      ..writeByte(8)
      ..write(obj.healthCondition)
      ..writeByte(9)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimedCheckSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
