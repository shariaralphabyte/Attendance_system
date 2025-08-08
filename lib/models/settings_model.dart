// models/settings_model.dart
class SettingsModel {
  final int? id;
  final String lateTime; // Format: HH:MM:SS
  final String workingStartTime; // Format: HH:MM:SS
  final int gracePeriodMinutes;
  final bool isSystemGeneratedIdEnabled;
  final String idFormat; // Format for auto-generated IDs
  final bool isBiometricEnabled;
  final bool isDualAuthEnabled; // QR + Biometric
  final DateTime createdAt;
  final DateTime updatedAt;

  SettingsModel({
    this.id,
    required this.lateTime,
    required this.workingStartTime,
    required this.gracePeriodMinutes,
    required this.isSystemGeneratedIdEnabled,
    required this.idFormat,
    required this.isBiometricEnabled,
    required this.isDualAuthEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lateTime': lateTime,
      'workingStartTime': workingStartTime,
      'gracePeriodMinutes': gracePeriodMinutes,
      'isSystemGeneratedIdEnabled': isSystemGeneratedIdEnabled ? 1 : 0,
      'idFormat': idFormat,
      'isBiometricEnabled': isBiometricEnabled ? 1 : 0,
      'isDualAuthEnabled': isDualAuthEnabled ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      id: map['id']?.toInt(),
      lateTime: map['lateTime'] ?? '09:00:00',
      workingStartTime: map['workingStartTime'] ?? '09:00:00',
      gracePeriodMinutes: map['gracePeriodMinutes']?.toInt() ?? 0,
      isSystemGeneratedIdEnabled: map['isSystemGeneratedIdEnabled'] == 1,
      idFormat: map['idFormat'] ?? 'DEPTYYMMDD###',
      isBiometricEnabled: map['isBiometricEnabled'] == 1,
      isDualAuthEnabled: map['isDualAuthEnabled'] == 1,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  SettingsModel copyWith({
    int? id,
    String? lateTime,
    String? workingStartTime,
    int? gracePeriodMinutes,
    bool? isSystemGeneratedIdEnabled,
    String? idFormat,
    bool? isBiometricEnabled,
    bool? isDualAuthEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SettingsModel(
      id: id ?? this.id,
      lateTime: lateTime ?? this.lateTime,
      workingStartTime: workingStartTime ?? this.workingStartTime,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      isSystemGeneratedIdEnabled: isSystemGeneratedIdEnabled ?? this.isSystemGeneratedIdEnabled,
      idFormat: idFormat ?? this.idFormat,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isDualAuthEnabled: isDualAuthEnabled ?? this.isDualAuthEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'SettingsModel{id: $id, lateTime: $lateTime, workingStartTime: $workingStartTime, gracePeriodMinutes: $gracePeriodMinutes, isSystemGeneratedIdEnabled: $isSystemGeneratedIdEnabled, idFormat: $idFormat, isBiometricEnabled: $isBiometricEnabled, isDualAuthEnabled: $isDualAuthEnabled, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}