// screens/add_user_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../utils/app_theme.dart';
import '../utils/database_helper.dart';
import '../models/user_model.dart';
import 'qr_code_display_screen.dart';

class AddUserScreen extends StatefulWidget {
  final UserModel? user; // For editing existing user

  const AddUserScreen({super.key, this.user});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedDepartment = 'Engineering';
  String _selectedPosition = 'Software Engineer';
  File? _selectedImage;
  bool _isLoading = false;
  bool _isEditingExistingUser = false; // Flag to check if we're editing an existing user

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _departments = [
    'Engineering',
    'Human Resources',
    'Marketing',
    'Sales',
    'Finance',
    'Operations',
    'Customer Service',
    'IT Support',
  ];

  final List<String> _positions = [
    'Software Engineer',
    'Senior Software Engineer',
    'Team Lead',
    'Project Manager',
    'HR Manager',
    'Marketing Specialist',
    'Sales Executive',
    'Financial Analyst',
    'Operations Manager',
    'Support Specialist',
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeForm();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  void _initializeForm() {
    if (widget.user != null) {
      final user = widget.user!;
      _employeeIdController.text = user.employeeId;
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      _selectedDepartment = user.department;
      _selectedPosition = user.position;
      _isEditingExistingUser = true; // Set flag when editing existing user
    } else {
      // For new users, generate ID automatically if enabled in settings
      _generateEmployeeId();
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Photo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ImageSourceButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () => _getImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ImageSourceButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () => _getImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    Navigator.pop(context);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _generateEmployeeId() async {
    // If editing existing user with system-generated ID, don't regenerate
    if (_isEditingExistingUser && widget.user?.isSystemGenerated == true) {
      return;
    }
    
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.millisecond}';
    final departmentCode = _selectedDepartment.substring(0, 2).toUpperCase();
    final employeeId = '$departmentCode$timestamp';

    setState(() {
      _employeeIdController.text = employeeId;
    });
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Determine if this is a system-generated ID
      final isSystemGenerated = widget.user == null || widget.user?.isSystemGenerated == true;
      
      final user = UserModel(
        id: widget.user?.id,
        employeeId: _employeeIdController.text.trim(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        department: _selectedDepartment,
        position: _selectedPosition,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        profileImage: _selectedImage?.path,
        isSystemGenerated: isSystemGenerated, // Set the isSystemGenerated flag
        createdAt: widget.user?.createdAt ?? DateTime.now().toIso8601String(),
      );

      if (widget.user != null) {
        await DatabaseHelper.instance.updateUser(user);
        _showSuccessMessage('Employee updated successfully!');
      } else {
        await DatabaseHelper.instance.insertUser(user);
        _showSuccessMessage('Employee added successfully!');

        // Show QR code generation dialog
        await Future.delayed(const Duration(milliseconds: 500));
        _showQRCodeDialog(user);
      }
    } catch (e) {
      print('Error saving user: $e');
      String errorMessage = 'Failed to save employee: ${e.toString()}';
      if (e.toString().contains('UNIQUE constraint failed')) {
        errorMessage = 'Employee ID already exists. Please use a different ID.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showQRCodeDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Generate ID Card & QR Code?'),
        content: Text(
          'Would you like to generate an ID card with QR code for ${user.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QRCodeDisplayScreen(user: user),
                ),
              );
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _employeeIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.user != null ? 'Edit Employee' : 'Add New Employee'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildForm(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 30),

            // Profile Image Section
            _buildProfileImageSection(),
            const SizedBox(height: 30),

            // Form Fields
            _buildFormFields(),
            const SizedBox(height: 40),

            // Save Button
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            widget.user != null ? Icons.edit : Icons.person_add,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user != null ? 'Edit Employee' : 'Add New Employee',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user != null
                      ? 'Update existing employee information'
                      : 'Create a new employee profile',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _selectedImage != null
                  ? FileImage(_selectedImage!)
                  : (widget.user?.profileImage != null
                        ? FileImage(File(widget.user!.profileImage!))
                        : const AssetImage('assets/images/default_user.png')
                              as ImageProvider),
              backgroundColor: Colors.grey.shade200,
            ),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    // Determine if employee ID field should be disabled
    final isEmployeeIdDisabled = _isEditingExistingUser && widget.user?.isSystemGenerated == true;
    
    return Column(
      children: [
        TextFormField(
          controller: _employeeIdController,
          enabled: !isEmployeeIdDisabled, // Disable if editing system-generated ID
          decoration: InputDecoration(
            labelText: 'Employee ID',
            suffixIcon: isEmployeeIdDisabled
              ? const Icon(Icons.lock, color: Colors.grey) // Show lock icon for disabled field
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _generateEmployeeId,
                  tooltip: 'Generate ID',
                ),
            hintText: isEmployeeIdDisabled ? 'System-generated ID (cannot be changed)' : null,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Employee ID is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Full Name'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Email'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email is required';
            }
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(labelText: 'Phone (optional)'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedDepartment,
          items: _departments.map((dept) {
            return DropdownMenuItem(value: dept, child: Text(dept));
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedDepartment = value!);
          },
          decoration: const InputDecoration(labelText: 'Department'),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedPosition,
          items: _positions.map((pos) {
            return DropdownMenuItem(value: pos, child: Text(pos));
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedPosition = value!);
          },
          decoration: const InputDecoration(labelText: 'Position'),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.save),
        label: Text(
          _isLoading
              ? 'Saving...'
              : widget.user != null
              ? 'Update Employee'
              : 'Save Employee',
        ),
        onPressed: _isLoading ? null : _saveUser,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
