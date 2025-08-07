// screens/attendance_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../utils/database_helper.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';

class AttendanceListScreen extends StatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen>
    with TickerProviderStateMixin {
  List<AttendanceModel> _allAttendance = [];
  List<AttendanceModel> _filteredAttendance = [];
  Map<String, UserModel> _usersMap = {};
  bool _isLoading = true;

  String _selectedFilter = 'All';
  DateTime? _selectedDate;
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _filterOptions = [
    'All',
    'Present',
    'Late',
    'Today',
    'This Week',
    'This Month',
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData();
    _searchController.addListener(_filterAttendance);
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  Future<void> _loadData() async {
    try {
      final attendance = await DatabaseHelper.instance.getAllAttendance();
      final users = await DatabaseHelper.instance.getAllUsers();

      final usersMap = <String, UserModel>{};
      for (final user in users) {
        usersMap[user.employeeId] = user;
      }

      setState(() {
        _allAttendance = attendance;
        _filteredAttendance = attendance;
        _usersMap = usersMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading attendance: $e')),
      );
    }
  }

  void _filterAttendance() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredAttendance = _allAttendance.where((attendance) {
        final user = _usersMap[attendance.employeeId];

        // Search filter
        final matchesSearch = query.isEmpty ||
            (user?.name.toLowerCase().contains(query) ?? false) ||
            attendance.employeeId.toLowerCase().contains(query) ||
            attendance.date.contains(query);

        // Status filter
        final matchesStatus = _selectedFilter == 'All' ||
            attendance.status == _selectedFilter ||
            (_selectedFilter == 'Today' && _isToday(attendance.date)) ||
            (_selectedFilter == 'This Week' && _isThisWeek(attendance.date)) ||
            (_selectedFilter == 'This Month' && _isThisMonth(attendance.date));

        // Date filter
        final matchesDate = _selectedDate == null ||
            attendance.date == DateFormat('yyyy-MM-dd').format(_selectedDate!);

        return matchesSearch && matchesStatus && matchesDate;
      }).toList();
    });
  }

  bool _isToday(String dateString) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return dateString == today;
  }

  bool _isThisWeek(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        date.isBefore(weekEnd.add(const Duration(days: 1)));
  }

  bool _isThisMonth(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
      _filterAttendance();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
    _filterAttendance();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Attendance Records'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Filters and Search
        _buildFiltersSection(),

        // Statistics
        _buildStatisticsSection(),

        // Attendance List
        Expanded(child: _buildAttendanceList()),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or employee ID...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                onPressed: () => _searchController.clear(),
                icon: const Icon(Icons.clear),
              )
                  : null,
            ),
          ),

          const SizedBox(height: 16),

          // Filter Row
          Row(
            children: [
              // Status Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter',
                    prefixIcon: Icon(Icons.filter_list),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  items: _filterOptions.map((filter) {
                    return DropdownMenuItem(
                      value: filter,
                      child: Text(filter),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                    });
                    _filterAttendance();
                  },
                ),
              ),

              const SizedBox(width: 16),

              // Date Filter
              Expanded(
                child: GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedDate != null
                                ? DateFormat('MMM dd, yyyy').format(
                                _selectedDate!)
                                : 'Select Date',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        if (_selectedDate != null)
                          GestureDetector(
                            onTap: _clearDateFilter,
                            child: const Icon(Icons.clear, size: 16),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    final totalRecords = _filteredAttendance.length;
    final presentCount = _filteredAttendance
        .where((a) => a.status == 'Present')
        .length;
    final lateCount = _filteredAttendance
        .where((a) => a.status == 'Late')
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem('Total', totalRecords.toString(), Icons.list),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.3),
          ),
          Expanded(
            child: _buildStatItem(
                'Present', presentCount.toString(), Icons.check_circle),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.3),
          ),
          Expanded(
            child: _buildStatItem(
                'Late', lateCount.toString(), Icons.access_time),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),

          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ]);

  }
  Widget _buildAttendanceList() {
    if (_filteredAttendance.isEmpty) {
      return const Center(
        child: Text(
          'No attendance records found.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredAttendance.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final attendance = _filteredAttendance[index];
        final user = _usersMap[attendance.employeeId];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppTheme.cardShadows,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                child: Icon(
                  Icons.person,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${attendance.employeeId}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: ${attendance.date}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${attendance.status}',
                      style: TextStyle(
                        fontSize: 14,
                        color: attendance.status == 'Late'
                            ? Colors.orange
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


