// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bluetooth_device_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BluetoothDeviceModelAdapter extends TypeAdapter<BluetoothDeviceModel> {
  @override
  final int typeId = 3;

  @override
  BluetoothDeviceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BluetoothDeviceModel(
      id: fields[0] as String,
      name: fields[1] as String,
      macAddress: fields[2] as String,
      isConnected: fields[3] as bool,
      lastConnected: fields[4] as DateTime,
      signalStrength: fields[5] as int,
      deviceType: fields[6] as String,
      isSaved: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, BluetoothDeviceModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.macAddress)
      ..writeByte(3)
      ..write(obj.isConnected)
      ..writeByte(4)
      ..write(obj.lastConnected)
      ..writeByte(5)
      ..write(obj.signalStrength)
      ..writeByte(6)
      ..write(obj.deviceType)
      ..writeByte(7)
      ..write(obj.isSaved);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDeviceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
