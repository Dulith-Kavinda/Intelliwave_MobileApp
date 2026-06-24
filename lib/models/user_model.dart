import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 1)
class UserModel {
  @HiveField(0)
  final String uid;
  
  @HiveField(1)
  final String email;
  
  @HiveField(2)
  final String name;
  
  @HiveField(3)
  final DateTime birthday;
  
  @HiveField(4)
  final double weight; // in kg
  
  @HiveField(5)
  final double height; // in cm
  
  @HiveField(6)
  final String bloodGroup;
  
  @HiveField(7)
  final String phoneNumber;
  
  @HiveField(8)
  final String? profilePictureUrl;
  
  @HiveField(9)
  final String address;
  
  @HiveField(10)
  final String gender;
  
  @HiveField(11)
  final DateTime createdAt;
  
  @HiveField(12)
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.birthday,
    required this.weight,
    required this.height,
    required this.bloodGroup,
    required this.phoneNumber,
    this.profilePictureUrl,
    required this.address,
    required this.gender,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns true when all required user-entered fields are filled.
  /// weight and height are excluded — they always have slider defaults.
  bool get isComplete {
    return name.trim().isNotEmpty &&
        phoneNumber.trim().isNotEmpty &&
        address.trim().isNotEmpty &&
        gender.trim().isNotEmpty &&
        bloodGroup.trim().isNotEmpty;
  }


  // Convert to JSON for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'birthday': birthday,
      'weight': weight,
      'height': height,
      'bloodGroup': bloodGroup,
      'phoneNumber': phoneNumber,
      'profilePictureUrl': profilePictureUrl,
      'address': address,
      'gender': gender,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime _parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return UserModel(
      uid: map['uid'] ?? map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      birthday: _parseDate(map['birthday']),
      weight: (map['weight'] ?? 0).toDouble(),
      height: (map['height'] ?? 0).toDouble(),
      bloodGroup: map['bloodGroup'] ?? map['blood_group'] ?? '',
      phoneNumber: map['phoneNumber'] ?? map['phone_number'] ?? '',
      profilePictureUrl: map['profilePictureUrl'] ?? map['profile_picture_url'],
      address: map['address'] ?? '',
      gender: map['gender'] ?? '',
      createdAt: _parseDate(map['createdAt'] ?? map['created_at']),
      updatedAt: _parseDate(map['updatedAt'] ?? map['updated_at']),
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    DateTime? birthday,
    double? weight,
    double? height,
    String? bloodGroup,
    String? phoneNumber,
    String? profilePictureUrl,
    String? address,
    String? gender,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      birthday: birthday ?? this.birthday,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
