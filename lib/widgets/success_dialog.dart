// widgets/success_dialog.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../utils/app_theme.dart';

class SuccessDialog extends StatefulWidget {
  final String title;
  final String message;
  final String type; // 'check_in' or 'check_out'
  final Map<String, String> data;
  final VoidCallback onDismiss;

  const SuccessDialog({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    required this.data,
    required this.onDismiss,
  });

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _startAnimations();
  }

  void _startAnimations() async {
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: _buildDialogContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogContent() {
    final isCheckIn = widget.type == 'check_in';
    final color = isCheckIn ? AppTheme.successColor : AppTheme.primaryColor;
    final gradient = isCheckIn ? AppTheme.secondaryGradient : AppTheme.primaryGradient;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success Animation/Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCheckIn ? Icons.login : Icons.logout,
              color: Colors.white,
              size: 50,
            ),
          ),

          const SizedBox(height: 24),

          // Title
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // Employee details card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  'Employee',
                  widget.data['name'] ?? '',
                  Icons.person,
                  color,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'ID',
                  widget.data['employeeId'] ?? '',
                  Icons.badge,
                  color,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  isCheckIn ? 'Check-in Time' : 'Check-out Time',
                  widget.data['time'] ?? '',
                  Icons.access_time,
                  color,
                ),
                if (isCheckIn && widget.data['status'] != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Status',
                    widget.data['status'] ?? '',
                    widget.data['status'] == 'Late' ? Icons.warning : Icons.check_circle,
                    widget.data['status'] == 'Late' ? AppTheme.warningColor : AppTheme.successColor,
                  ),
                ],
                if (!isCheckIn && widget.data['workingHours'] != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Working Hours',
                    widget.data['workingHours'] ?? '',
                    Icons.schedule,
                    color,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Message
          Text(
            widget.message,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // OK Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onDismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}