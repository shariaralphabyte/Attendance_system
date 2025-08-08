// screens/biometric_auth_screen.dart
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../utils/app_theme.dart';
import '../services/biometric_service.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../utils/database_helper.dart';
import '../widgets/success_dialog.dart';
import 'qr_scanner_screen.dart';

class BiometricAuthScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onAttendanceMarked;

  const BiometricAuthScreen({
    super.key,
    required this.user,
    this.onAttendanceMarked,
  });

  @override
  State<BiometricAuthScreen> createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool _isAuthenticating = false;
  String _authMessage = 'Please authenticate to continue';

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _getAuthMessage();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);
  }

  Future<void> _getAuthMessage() async {
    final String message = await BiometricService.getAuthMessage();
    setState(() {
      _authMessage = message;
    });
  }

  Future<void> _authenticateUser() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    try {
      // Perform biometric authentication
      final bool didAuthenticate = await BiometricService.authenticate(
        localizedReason: 'Scan your fingerprint or face to mark attendance',
      );

      if (didAuthenticate) {
        // Authentication successful, mark attendance
        await _markAttendance();
      } else {
        // Authentication failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication failed'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  Future<void> _markAttendance() async {
    try {
      final now = DateTime.now();
      final time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      final date = now.toIso8601String().split('T')[0];

      // Get settings for configurable late time
      final settings = await DatabaseHelper.instance.getSettings();
      final lateTime = settings?.lateTime ?? '09:00:00';

      // Determine status (Present or Late - using configurable time)
      final standardTime = DateTime.parse('${date}T$lateTime');
      final currentTime = DateTime.parse('${date}T$time');
      final status = currentTime.isAfter(standardTime) ? 'Late' : 'Present';

      final attendance = AttendanceModel(
        employeeId: widget.user.employeeId,
        date: date,
        checkInTime: time,
        status: status,
        createdAt: now.toIso8601String(),
      );

      await DatabaseHelper.instance.insertAttendance(attendance);

      if (mounted) {
        _showSuccessDialog(
          'Attendance Marked',
          '${widget.user.name} has been marked ${status.toLowerCase()} at $time',
          'check_in',
          {
            'name': widget.user.name,
            'time': time,
            'status': status,
            'employeeId': widget.user.employeeId,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking attendance: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(
      String title, String message, String type, Map<String, String> data) {
    if (mounted) {
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Biometric Authentication'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.fingerprint,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biometric Authentication',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Authenticate to mark attendance',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // User Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadows,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      color: AppTheme.primaryColor,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${widget.user.employeeId}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Biometric Icon with Animation
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 40),

            // Authentication Message
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                _authMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                  height: 1.5,
                ),
              ),
            ),

            const Spacer(),

            // Authenticate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAuthenticating ? null : _authenticateUser,
                icon: _isAuthenticating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.fingerprint),
                label: Text(
                  _isAuthenticating ? 'Authenticating...' : 'Authenticate',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: AppTheme.errorColor),
                  foregroundColor: AppTheme.errorColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}