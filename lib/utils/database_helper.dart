// utils/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../models/settings_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employeeId TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        department TEXT NOT NULL,
        position TEXT NOT NULL,
        phone TEXT,
        profileImage TEXT,
        isSystemGenerated INTEGER DEFAULT 0, -- 0 = false, 1 = true
        createdAt TEXT NOT NULL
      )
    ''');

    // Attendance table
    await db.execute('''
      CREATE TABLE attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employeeId TEXT NOT NULL,
        date TEXT NOT NULL,
        checkInTime TEXT NOT NULL,
        checkOutTime TEXT,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (employeeId) REFERENCES users (employeeId),
        UNIQUE(employeeId, date)
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE settings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lateTime TEXT NOT NULL DEFAULT '09:00:00',
        workingStartTime TEXT NOT NULL DEFAULT '09:00:00',
        gracePeriodMinutes INTEGER NOT NULL DEFAULT 0,
        isSystemGeneratedIdEnabled INTEGER NOT NULL DEFAULT 1, -- 0 = false, 1 = true
        idFormat TEXT NOT NULL DEFAULT 'DEPTYYMMDD###',
        isBiometricEnabled INTEGER NOT NULL DEFAULT 0, -- 0 = false, 1 = true
        isDualAuthEnabled INTEGER NOT NULL DEFAULT 0, -- 0 = false, 1 = true
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_employee_id ON users(employeeId)');
    await db.execute('CREATE INDEX idx_attendance_employee ON attendance(employeeId)');
    await db.execute('CREATE INDEX idx_attendance_date ON attendance(date)');
  }

  // User CRUD Operations
  Future<int> insertUser(UserModel user) async {
    final db = await instance.database;
    try {
      return await db.insert('users', user.toMap());
    } catch (e) {
      throw Exception('Failed to insert user: $e');
    }
  }

  Future<UserModel?> getUserByEmployeeId(String employeeId) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'employeeId = ?',
      whereArgs: [employeeId],
    );

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await instance.database;
    final maps = await db.query('users', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => UserModel.fromMap(maps[i]));
  }

  Future<int> updateUser(UserModel user) async {
    final db = await instance.database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'employeeId = ?',
      whereArgs: [user.employeeId],
    );
  }

  Future<int> deleteUser(String employeeId) async {
    final db = await instance.database;
    // Delete user and their attendance records
    await db.delete('attendance', where: 'employeeId = ?', whereArgs: [employeeId]);
    return await db.delete('users', where: 'employeeId = ?', whereArgs: [employeeId]);
  }

  // Attendance CRUD Operations
  Future<int> insertAttendance(AttendanceModel attendance) async {
    final db = await instance.database;
    try {
      return await db.insert('attendance', attendance.toMap());
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        throw Exception('Attendance already marked for today');
      }
      throw Exception('Failed to insert attendance: $e');
    }
  }

  Future<AttendanceModel?> getAttendanceByDate(String employeeId, String date) async {
    final db = await instance.database;
    final maps = await db.query(
      'attendance',
      where: 'employeeId = ? AND date = ?',
      whereArgs: [employeeId, date],
    );

    if (maps.isNotEmpty) {
      return AttendanceModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<AttendanceModel>> getAttendanceByEmployee(String employeeId) async {
    final db = await instance.database;
    final maps = await db.query(
      'attendance',
      where: 'employeeId = ?',
      whereArgs: [employeeId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => AttendanceModel.fromMap(maps[i]));
  }

  Future<List<AttendanceModel>> getAllAttendance() async {
    final db = await instance.database;
    final maps = await db.query('attendance', orderBy: 'date DESC, createdAt DESC');
    return List.generate(maps.length, (i) => AttendanceModel.fromMap(maps[i]));
  }

  Future<int> updateAttendanceCheckOut(String employeeId, String date, String checkOutTime) async {
    final db = await instance.database;
    return await db.update(
      'attendance',
      {'checkOutTime': checkOutTime},
      where: 'employeeId = ? AND date = ?',
      whereArgs: [employeeId, date],
    );
  }

  // Statistics Methods
  Future<Map<String, dynamic>> getAttendanceStats(String employeeId) async {
    final db = await instance.database;

    final totalDays = await db.rawQuery(
      'SELECT COUNT(*) as count FROM attendance WHERE employeeId = ?',
      [employeeId],
    );

    final presentDays = await db.rawQuery(
      'SELECT COUNT(*) as count FROM attendance WHERE employeeId = ? AND status = ?',
      [employeeId, 'Present'],
    );

    final lateDays = await db.rawQuery(
      'SELECT COUNT(*) as count FROM attendance WHERE employeeId = ? AND status = ?',
      [employeeId, 'Late'],
    );

    return {
      'totalDays': totalDays.first['count'] ?? 0,
      'presentDays': presentDays.first['count'] ?? 0,
      'lateDays': lateDays.first['count'] ?? 0,
      'absences': 0, // Can be calculated based on working days
    };
  }

  Future<List<Map<String, dynamic>>> getMonthlyAttendance(String employeeId, int year, int month) async {
    final db = await instance.database;
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endDate = '$year-${month.toString().padLeft(2, '0')}-31';

    final maps = await db.query(
      'attendance',
      where: 'employeeId = ? AND date >= ? AND date <= ?',
      whereArgs: [employeeId, startDate, endDate],
      orderBy: 'date ASC',
    );

    return maps;
  }

  // Settings CRUD Operations
  Future<int> insertSettings(SettingsModel settings) async {
    final db = await instance.database;
    try {
      return await db.insert('settings', settings.toMap());
    } catch (e) {
      throw Exception('Failed to insert settings: $e');
    }
  }

  Future<SettingsModel?> getSettings() async {
    final db = await instance.database;
    final maps = await db.query('settings', limit: 1);
    
    if (maps.isNotEmpty) {
      return SettingsModel.fromMap(maps.first);
    }
    
    // If no settings exist, create default settings
    final defaultSettings = SettingsModel(
      lateTime: '09:00:00',
      workingStartTime: '09:00:00',
      gracePeriodMinutes: 0,
      isSystemGeneratedIdEnabled: true,
      idFormat: 'DEPTYYMMDD###',
      isBiometricEnabled: false,
      isDualAuthEnabled: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await insertSettings(defaultSettings);
    return defaultSettings;
  }

  Future<int> updateSettings(SettingsModel settings) async {
    final db = await instance.database;
    return await db.update(
      'settings',
      settings.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [settings.id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}