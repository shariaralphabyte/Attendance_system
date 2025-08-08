// models/user_model.dart
class UserModel {
  final int? id;
  final String employeeId;
  final String name;
  final String email;
  final String department;
  final String position;
  final String? phone;
  final String? profileImage;
  final bool isSystemGenerated; // New field for system-generated IDs
  final String createdAt;

  UserModel({
    this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.department,
    required this.position,
    this.phone,
    this.profileImage,
    this.isSystemGenerated = false, // Default to false
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'name': name,
      'email': email,
      'department': department,
      'position': position,
      'phone': phone,
      'profileImage': profileImage,
      'isSystemGenerated': isSystemGenerated ? 1 : 0, // Store as integer in database
      'createdAt': createdAt,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toInt(),
      employeeId: map['employeeId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      department: map['department'] ?? '',
      position: map['position'] ?? '',
      phone: map['phone'],
      profileImage: map['profileImage'],
      isSystemGenerated: map['isSystemGenerated'] == 1, // Convert from integer
      createdAt: map['createdAt'] ?? '',
    );
  }

  UserModel copyWith({
    int? id,
    String? employeeId,
    String? name,
    String? email,
    String? department,
    String? position,
    String? phone,
    String? profileImage,
    bool? isSystemGenerated,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      email: email ?? this.email,
      department: department ?? this.department,
      position: position ?? this.position,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      isSystemGenerated: isSystemGenerated ?? this.isSystemGenerated,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserModel{id: $id, employeeId: $employeeId, name: $name, email: $email, department: $department, position: $position, isSystemGenerated: $isSystemGenerated}';
  }
}