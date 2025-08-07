// models/attendance_model.dart
class AttendanceModel {
  final int? id;
  final String employeeId;
  final String date;
  final String checkInTime;
  final String? checkOutTime;
  final String status; // Present, Late, Absent
  final String createdAt;

  AttendanceModel({
    this.id,
    required this.employeeId,
    required this.date,
    required this.checkInTime,
    this.checkOutTime,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'date': date,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'status': status,
      'createdAt': createdAt,
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id']?.toInt(),
      employeeId: map['employeeId'] ?? '',
      date: map['date'] ?? '',
      checkInTime: map['checkInTime'] ?? '',
      checkOutTime: map['checkOutTime'],
      status: map['status'] ?? '',
      createdAt: map['createdAt'] ?? '',
    );
  }

  AttendanceModel copyWith({
    int? id,
    String? employeeId,
    String? date,
    String? checkInTime,
    String? checkOutTime,
    String? status,
    String? createdAt,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper methods
  Duration? get workingHours {
    if (checkOutTime == null) return null;

    try {
      final checkIn = DateTime.parse('${date}T$checkInTime');
      final checkOut = DateTime.parse('${date}T$checkOutTime');
      return checkOut.difference(checkIn);
    } catch (e) {
      return null;
    }
  }

  String get formattedWorkingHours {
    final duration = workingHours;
    if (duration == null) return 'Still working';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  bool get isLate {
    try {
      final checkIn = DateTime.parse('${date}T$checkInTime');
      final standardTime = DateTime.parse('${date}T09:00:00'); // 9 AM standard
      return checkIn.isAfter(standardTime);
    } catch (e) {
      return false;
    }
  }

  @override
  String toString() {
    return 'AttendanceModel{id: $id, employeeId: $employeeId, date: $date, checkInTime: $checkInTime, status: $status}';
  }
}