// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_theme.dart';
import '../utils/database_helper.dart';
import '../models/user_model.dart';
import 'add_user_screen.dart';
import 'attendance_list_screen.dart';
import 'biometric_auth_screen.dart';
import 'qr_scanner_screen.dart';
import 'settings_screen.dart';
import 'user_list_screen.dart';
import '../utils/database_helper.dart';
import '../widgets/permission_dialog.dart';
import '../widgets/stats_card.dart';
import '../widgets/quick_action_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int totalUsers = 0;
  int todayAttendance = 0;
  List<UserModel> recentUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadDashboardData();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));

    _animationController.forward();
  }

  Future<void> _loadDashboardData() async {
    try {
      final users = await DatabaseHelper.instance.getAllUsers();
      final today = DateTime.now().toIso8601String().split('T')[0];
      final attendanceList = await DatabaseHelper.instance.getAllAttendance();
      final todayAttendanceCount = attendanceList
          .where((attendance) => attendance.date == today)
          .length;

      setState(() {
        totalUsers = users.length;
        todayAttendance = todayAttendanceCount;
        recentUsers = users.take(3).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      _navigateToScanner();
    } else if (status.isDenied) {
      _showPermissionDialog();
    } else if (status.isPermanentlyDenied) {
      _showPermissionSettingsDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionDialog(
        title: 'Camera Permission Required',
        message: 'This app needs camera access to scan QR codes for attendance marking.',
        onGranted: () async {
          final status = await Permission.camera.request();
          if (status.isGranted) {
            _navigateToScanner();
          }
        },
      ),
    );
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Permission Required'),
        content: const Text(
          'Camera permission is permanently denied. Please enable it from app settings to scan QR codes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _navigateToScanner() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => QRScannerScreen(
          onAttendanceMarked: _loadDashboardData,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
 }

 void _navigateToBiometricAuth() async {
   // Get all users to allow selection
   final users = await DatabaseHelper.instance.getAllUsers();
   
   if (users.isEmpty) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('No employees found. Please add employees first.'),
           backgroundColor: AppTheme.errorColor,
         ),
       );
     }
     return;
   }
   
   // For now, we'll just use the first user as an example
   // In a real implementation, you would show a user selection dialog
   final user = users.first;
   
   if (mounted) {
     Navigator.push(
       context,
       PageRouteBuilder(
         pageBuilder: (context, animation, _) => BiometricAuthScreen(
           user: user,
           onAttendanceMarked: _loadDashboardData,
         ),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           const begin = Offset(0.0, 1.0);
           const end = Offset.zero;
           const curve = Curves.easeInOut;
           
           var tween = Tween(begin: begin, end: end).chain(
             CurveTween(curve: curve),
           );
           
           return SlideTransition(
             position: animation.drive(tween),
             child: child,
           );
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
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildContent(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return CustomScrollView(
      slivers: [
        // Custom App Bar
        SliverAppBar(
          expandedHeight: 120,
          floating: false,
          pinned: true,
          elevation: 0,
          backgroundColor: AppTheme.backgroundColor,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text(
              'Smart Attendance',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
            ),
          ),
          actions: [
            IconButton(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                ).then((_) => _loadDashboardData());
              },
              icon: const Icon(Icons.settings, color: Colors.white),
            ),
          ],
        ),

        // Main Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                _buildWelcomeSection(),
                const SizedBox(height: 30),

                // Stats Cards
                _buildStatsSection(),
                const SizedBox(height: 30),

                // Quick Actions
                _buildQuickActionsSection(),
                const SizedBox(height: 30),

                // Recent Users
                if (recentUsers.isNotEmpty) _buildRecentUsersSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.secondaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage attendance with ease',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.waving_hand,
              size: 32,
              color: Colors.white,
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
          'Today\'s Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'Total Users',
                value: totalUsers.toString(),
                icon: Icons.people,
                color: AppTheme.primaryColor,
                gradient: AppTheme.primaryGradient,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatsCard(
                title: 'Today\'s Attendance',
                value: todayAttendance.toString(),
                icon: Icons.check_circle,
                color: AppTheme.successColor,
                gradient: AppTheme.secondaryGradient,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            QuickActionCard(
              title: 'Scan QR',
              subtitle: 'Mark attendance',
              icon: Icons.qr_code_scanner,
              gradient: AppTheme.primaryGradient,
              onTap: _checkCameraPermission,
            ),
            QuickActionCard(
              title: 'Biometric Auth',
              subtitle: 'Mark attendance',
              icon: Icons.fingerprint,
              gradient: AppTheme.accentGradient,
              onTap: _navigateToBiometricAuth,
            ),
            QuickActionCard(
              title: 'Add User',
              subtitle: 'Register new employee',
              icon: Icons.person_add,
              gradient: AppTheme.secondaryGradient,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddUserScreen()),
              ).then((_) => _loadDashboardData()),
            ),
            QuickActionCard(
              title: 'View Users',
              subtitle: 'Manage employees',
              icon: Icons.group,
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserListScreen()),
              ),
           QuickActionCard(
             title: 'Attendance Log',
             subtitle: 'View all records',
             icon: Icons.history,
             gradient: LinearGradient(
               colors: [Colors.orange.shade400, Colors.orange.shade600],
             ),
             onTap: () => Navigator.push(
               context,
               MaterialPageRoute(builder: (context) => const AttendanceListScreen()),
             ),
           ),
         ],
        ),
      ],
    );
  }

  Widget _buildRecentUsersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Users',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserListScreen()),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...recentUsers.map((user) => _buildUserCard(user)),
      ],
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.position} • ${user.department}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              user.employeeId,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}