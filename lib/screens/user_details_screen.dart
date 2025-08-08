// screens/user_details_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import '../utils/app_theme.dart';
import '../utils/database_helper.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import 'add_user_screen.dart';
import 'qr_code_display_screen.dart';

class UserDetailsScreen extends StatefulWidget {
  final UserModel user;

  const UserDetailsScreen({super.key, required this.user});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<AttendanceModel> _attendanceRecords = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initAnimations();
    _loadData();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  Future<void> _loadData() async {
    try {
      final attendance = await DatabaseHelper.instance.getAttendanceByEmployee(
        widget.user.employeeId,
      );
      final stats = await DatabaseHelper.instance.getAttendanceStats(
        widget.user.employeeId,
      );

      setState(() {
        _attendanceRecords = attendance;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: _buildContent(),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // Custom App Bar with Profile
        SliverAppBar(
          expandedHeight: 300,
          floating: false,
          pinned: true,
          backgroundColor: AppTheme.primaryColor,
          flexibleSpace: FlexibleSpaceBar(background: _buildProfileHeader()),
          actions: [
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'qr',
                  child: Row(
                    children: [
                      Icon(Icons.qr_code, size: 20),
                      SizedBox(width: 8),
                      Text('View QR Code'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'biometric',
                  child: Row(
                    children: [
                      Icon(Icons.fingerprint, size: 20),
                      SizedBox(width: 8),
                      Text('Register Biometric'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // Tab Bar
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Attendance'),
              ],
            ),
          ),
        ),

        // Tab Content
        SliverFillRemaining(
          child: TabBarView(
            controller: _tabController,
            children: [_buildOverviewTab(), _buildAttendanceTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60), // Space for app bar
              // Profile Image
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: widget.user.profileImage != null
                    ? ClipOval(
                        child: Image.file(
                          File(widget.user.profileImage!),
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
              ),

              const SizedBox(height: 20),

              // Name and Position
              Text(
                widget.user.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                widget.user.position,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 4),

              Text(
                widget.user.department,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employee Information Card
          _buildInfoCard(),

          const SizedBox(height: 20),

          // Statistics Cards
          _buildStatsSection(),

          const SizedBox(height: 20),

          // Recent Attendance
          _buildRecentAttendanceSection(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Employee Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            _buildInfoRow(Icons.badge, 'Employee ID', widget.user.employeeId),
            _buildInfoRow(Icons.email, 'Email', widget.user.email),
            if (widget.user.phone != null)
              _buildInfoRow(Icons.phone, 'Phone', widget.user.phone!),
            _buildInfoRow(Icons.business, 'Department', widget.user.department),
            _buildInfoRow(Icons.work, 'Position', widget.user.position),
            _buildInfoRow(
              Icons.calendar_today,
              'Joined',
              DateTime.parse(widget.user.createdAt).toString().split(' ')[0],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance Statistics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Days',
                _stats['totalDays']?.toString() ?? '0',
                Icons.calendar_month,
                AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Present',
                _stats['presentDays']?.toString() ?? '0',
                Icons.check_circle,
                AppTheme.successColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Late',
                _stats['lateDays']?.toString() ?? '0',
                Icons.access_time,
                AppTheme.warningColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Attendance Rate',
                _calculateAttendanceRate(),
                Icons.trending_up,
                AppTheme.secondaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAttendanceSection() {
    final recentAttendance = _attendanceRecords.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Attendance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (recentAttendance.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No attendance records yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...recentAttendance.map(
            (attendance) => _buildAttendanceCard(attendance),
          ),
      ],
    );
  }

  Widget _buildAttendanceTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Filter options could go here
        Expanded(
          child: _attendanceRecords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No attendance records',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Attendance records will appear here once scanning begins',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _attendanceRecords.length,
                  itemBuilder: (context, index) {
                    return _buildAttendanceCard(_attendanceRecords[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCard(AttendanceModel attendance) {
    final statusColor = attendance.status == 'Present'
        ? AppTheme.successColor
        : attendance.status == 'Late'
        ? AppTheme.warningColor
        : AppTheme.errorColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                attendance.status == 'Present'
                    ? Icons.check_circle
                    : attendance.status == 'Late'
                    ? Icons.access_time
                    : Icons.cancel,
                color: statusColor,
                size: 24,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attendance.date,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check-in: ${attendance.checkInTime}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (attendance.checkOutTime != null)
                    Text(
                      'Check-out: ${attendance.checkOutTime}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    attendance.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  attendance.formattedWorkingHours,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _calculateAttendanceRate() {
    final totalDays = _stats['totalDays'] as int? ?? 0;
    final presentDays = _stats['presentDays'] as int? ?? 0;

    if (totalDays == 0) return '0%';

    final rate = (presentDays / totalDays * 100).round();
    return '$rate%';
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddUserScreen(user: widget.user),
          ),
        );
        break;
      case 'qr':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QRCodeDisplayScreen(user: widget.user),
          ),
        );
        break;
    }
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppTheme.backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
