// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'heartbeat_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HeartbeatDataAdapter extends TypeAdapter<HeartbeatData> {
  @override
  final int typeId = 2;

  @override
  HeartbeatData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HeartbeatData(
      id: fields[0] as String,
      userId: fields[1] as String,
      heartRate: fields[2] as int,
      timestamp: fields[3] as DateTime,
      deviceId: fields[4] as String,
      status: fields[5] as String,
      oxygenLevel: fields[6] as double?,
      systolic: fields[7] as double?,
      diastolic: fields[8] as double?,
      ecgData: (fields[9] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, HeartbeatData obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.heartRate)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.deviceId)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.oxygenLevel)
      ..writeByte(7)
      ..write(obj.systolic)
      ..writeByte(8)
      ..write(obj.diastolic)
      ..writeByte(9)
      ..write(obj.ecgData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeartbeatDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
