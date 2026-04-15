import 'package:hive/hive.dart';

part 'bluetooth_device_model.g.dart';

@HiveType(typeId: 3)
class BluetoothDeviceModel {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String macAddress;
  
  @HiveField(3)
  final bool isConnected;
  
  @HiveField(4)
  final DateTime lastConnected;
  
  @HiveField(5)
  final int signalStrength; // RSSI
  
  @HiveField(6)
  final String deviceType; // 'heartbeat', 'smartwatch', etc.
  
  @HiveField(7)
  final bool isSaved;

  BluetoothDeviceModel({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.isConnected,
    required this.lastConnected,
    required this.signalStrength,
    required this.deviceType,
    required this.isSaved,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'macAddress': macAddress,
      'isConnected': isConnected,
      'lastConnected': lastConnected,
      'signalStrength': signalStrength,
      'deviceType': deviceType,
      'isSaved': isSaved,
    };
  }

  factory BluetoothDeviceModel.fromMap(Map<String, dynamic> map) {
    return BluetoothDeviceModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      macAddress: map['macAddress'] ?? '',
      isConnected: map['isConnected'] ?? false,
      lastConnected: map['lastConnected']?.toDate() ?? DateTime.now(),
      signalStrength: map['signalStrength'] ?? 0,
      deviceType: map['deviceType'] ?? 'heartbeat',
      isSaved: map['isSaved'] ?? false,
    );
  }

  BluetoothDeviceModel copyWith({
    String? id,
    String? name,
    String? macAddress,
    bool? isConnected,
    DateTime? lastConnected,
    int? signalStrength,
    String? deviceType,
    bool? isSaved,
  }) {
    return BluetoothDeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      isConnected: isConnected ?? this.isConnected,
      lastConnected: lastConnected ?? this.lastConnected,
      signalStrength: signalStrength ?? this.signalStrength,
      deviceType: deviceType ?? this.deviceType,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}
