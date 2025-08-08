// screens/qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner_widget.dart';
import '../utils/app_theme.dart';
import '../utils/database_helper.dart';
import '../models/attendance_model.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
import '../widgets/success_dialog.dart';

class QRScannerScreen extends StatefulWidget {
  final VoidCallback? onAttendanceMarked;

  const QRScannerScreen({super.key, this.onAttendanceMarked});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isProcessing = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  Future<void> _handleQRDetected(String qrCode, String type) async {
    final now = DateTime.now();

    // Prevent duplicate or too frequent scans (2 seconds cooldown)
    if (_isProcessing ||
        (_lastScanTime != null &&
            now.difference(_lastScanTime!) < const Duration(seconds: 2) &&
            _lastScannedCode == qrCode)) {
      return;
    }

    _lastScannedCode = qrCode;
    _lastScanTime = now;

    setState(() {
      _isProcessing = true;
    });

    try {
      final employeeId = qrCode.trim();

      final user = await DatabaseHelper.instance.getUserByEmployeeId(employeeId);
      if (user == null) {
        _showErrorDialog('Employee not found', 'No employee found with ID: $employeeId');
        return;
      }

      // Check if biometric authentication is required
      final settings = await DatabaseHelper.instance.getSettings();
      final isBiometricRequired = settings?.isBiometricEnabled ?? false;
      final isDualAuthRequired = settings?.isDualAuthEnabled ?? false;

      // If dual authentication is enabled, we need both QR and biometric
      if (isDualAuthRequired) {
        // Navigate to biometric authentication screen with dual auth flag
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BiometricAuthScreen(
                user: user,
                onAttendanceMarked: widget.onAttendanceMarked,
                isDualAuth: true,
              ),
            ),
          ).then((_) {
            setState(() {
              _isProcessing = false;
            });
          });
        }
        return;
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      final existingAttendance = await DatabaseHelper.instance.getAttendanceByDate(employeeId, today);

      if (existingAttendance != null) {
        if (existingAttendance.checkOutTime == null) {
          await _handleCheckOut(existingAttendance, user.name);
        } else {
          _showErrorDialog('Already marked', '${user.name} has already completed attendance for today.');
        }
      } else {
        await _handleCheckIn(employeeId, user.name);
      }

    } catch (e) {
      _showErrorDialog('Error', 'Failed to process attendance: $e');
    } finally {
      await Future.delayed(const Duration(seconds: 1)); // Small delay to smooth UI
      setState(() {
        _isProcessing = false;
      });
    }
  }


  Future<void> _handleCheckIn(String employeeId, String userName) async {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final date = now.toIso8601String().split('T')[0];

    // Get settings for configurable late time and grace period
    final settings = await DatabaseHelper.instance.getSettings();
    final lateTime = settings?.lateTime ?? '09:00:00';
    final gracePeriodMinutes = settings?.gracePeriodMinutes ?? 0;
    
    // Determine status (Present or Late - using configurable time with grace period)
    final standardTime = DateTime.parse('${date}T$lateTime');
    final gracePeriodEndTime = standardTime.add(Duration(minutes: gracePeriodMinutes));
    final currentTime = DateTime.parse('${date}T$time');
    final status = currentTime.isAfter(gracePeriodEndTime) ? 'Late' : 'Present';

    final attendance = AttendanceModel(
      employeeId: employeeId,
      date: date,
      checkInTime: time,
      status: status,
      createdAt: now.toIso8601String(),
    );

    await DatabaseHelper.instance.insertAttendance(attendance);

    _showSuccessDialog(
      'Check-In Successful',
      '$userName has been marked ${status.toLowerCase()} at $time',
      'check_in',
      {
        'name': userName,
        'time': time,
        'status': status,
        'employeeId': employeeId,
      },
    );
  }

  Future<void> _handleCheckOut(AttendanceModel attendance, String userName) async {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    await DatabaseHelper.instance.updateAttendanceCheckOut(
      attendance.employeeId,
      attendance.date,
      time,
    );

    // Calculate working hours
    final checkIn = DateTime.parse('${attendance.date}T${attendance.checkInTime}');
    final checkOut = DateTime.parse('${attendance.date}T$time');
    final workingHours = checkOut.difference(checkIn);

    final hours = workingHours.inHours;
    final minutes = workingHours.inMinutes.remainder(60);

    _showSuccessDialog(
      'Check-Out Successful',
      '$userName checked out at $time\nWorking hours: ${hours}h ${minutes}m',
      'check_out',
      {
        'name': userName,
        'time': time,
        'workingHours': '${hours}h ${minutes}m',
        'employeeId': attendance.employeeId,
      },
    );
  }

  void _showSuccessDialog(String title, String message, String type, Map<String, String> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SuccessDialog(
        title: title,
        message: message,
        type: type,
        data: data,
        onDismiss: () {
          Navigator.pop(context);
          Navigator.pop(context);
          widget.onAttendanceMarked?.call();
        },
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error, color: AppTheme.errorColor),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isProcessing = false;
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // QR Scanner Widget
          Positioned.fill(
            child: UltraQrScannerWidget(
              onCodeDetected: _handleQRDetected,
              showFlashToggle: true,
              autoStop: false,
              showStartStopButton: false,
              autoStart: true,
              overlay: _buildCustomOverlay(),
            ),
          ),

          // Processing overlay
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildCustomOverlay() {
    return Stack(
      children: [
        // Semi-transparent background
        Container(
          color: Colors.black.withOpacity(0.6),
        ),

        // Instructions at top
        Positioned(
          top: 60,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Scan Employee QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Position the QR code within the scanning area',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // Animated scanning frame
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      // Corner decorations
                      ...List.generate(4, (index) {
                        return Positioned(
                          top: index < 2 ? 0 : null,
                          bottom: index >= 2 ? 0 : null,
                          left: index % 2 == 0 ? 0 : null,
                          right: index % 2 == 1 ? 0 : null,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.only(
                                topLeft: index == 0 ? const Radius.circular(16) : Radius.zero,
                                topRight: index == 1 ? const Radius.circular(16) : Radius.zero,
                                bottomLeft: index == 2 ? const Radius.circular(16) : Radius.zero,
                                bottomRight: index == 3 ? const Radius.circular(16) : Radius.zero,
                              ),
                            ),
                          ),
                        );
                      }),

                      // Center crosshair
                      Center(
                        child: Icon(
                          Icons.center_focus_strong,
                          color: AppTheme.primaryColor.withOpacity(0.5),
                          size: 50,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom instructions
        Positioned(
          bottom: 100,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.secondaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Hold steady and ensure good lighting for better scanning',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
              const SizedBox(height: 20),
              const Text(
                'Processing...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Marking attendance',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}