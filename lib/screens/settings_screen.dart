// screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/database_helper.dart';
import '../models/settings_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late SettingsModel _settings;
  bool _isLoading = true;

  final _lateTimeController = TextEditingController();
  final _workingStartTimeController = TextEditingController();
  final _gracePeriodController = TextEditingController();
  final _idFormatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await DatabaseHelper.instance.getSettings();
      if (settings != null) {
        setState(() {
          _settings = settings;
          _isLoading = false;
          
          // Initialize controllers with current settings
          _lateTimeController.text = _settings.lateTime;
          _workingStartTimeController.text = _settings.workingStartTime;
          _gracePeriodController.text = _settings.gracePeriodMinutes.toString();
          _idFormatController.text = _settings.idFormat;
        });
      } else {
        // If settings is null, show error and create default settings
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading settings. Creating default settings...'),
            backgroundColor: Colors.orange,
          ),
        );
        
        // Try to create default settings
        await _createDefaultSettings();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading settings: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
  
  Future<void> _createDefaultSettings() async {
    try {
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
      
      await DatabaseHelper.instance.insertSettings(defaultSettings);
      
      setState(() {
        _settings = defaultSettings;
        
        // Initialize controllers with default settings
        _lateTimeController.text = _settings.lateTime;
        _workingStartTimeController.text = _settings.workingStartTime;
        _gracePeriodController.text = _settings.gracePeriodMinutes.toString();
        _idFormatController.text = _settings.idFormat;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default settings created successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create default settings: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedSettings = _settings.copyWith(
        lateTime: _lateTimeController.text,
        workingStartTime: _workingStartTimeController.text,
        gracePeriodMinutes: int.tryParse(_gracePeriodController.text) ?? 0,
        idFormat: _idFormatController.text,
        updatedAt: DateTime.now(),
      );

      await DatabaseHelper.instance.updateSettings(updatedSettings);
      
      setState(() {
        _settings = updatedSettings;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _lateTimeController.dispose();
    _workingStartTimeController.dispose();
    _gracePeriodController.dispose();
    _idFormatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('System Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            Icons.settings,
                            color: Colors.white,
                            size: 32,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'System Configuration',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Configure attendance system parameters',
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

                    const SizedBox(height: 30),

                    // Time Settings Section
                    _buildSectionHeader('Time Settings'),
                    const SizedBox(height: 16),
                    
                    _buildTimeField(
                      controller: _lateTimeController,
                      label: 'Late Time',
                      hint: 'HH:MM:SS (e.g., 09:00:00)',
                      validator: _validateTimeFormat,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildTimeField(
                      controller: _workingStartTimeController,
                      label: 'Working Start Time',
                      hint: 'HH:MM:SS (e.g., 09:00:00)',
                      validator: _validateTimeFormat,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildNumberField(
                      controller: _gracePeriodController,
                      label: 'Grace Period (minutes)',
                      hint: 'Minutes after late time before marking as late',
                      validator: _validateNumber,
                    ),

                    const SizedBox(height: 30),

                    // ID Settings Section
                    _buildSectionHeader('ID Settings'),
                    const SizedBox(height: 16),
                    
                    SwitchListTile(
                      title: const Text('Auto-Generate Employee IDs'),
                      subtitle: const Text('System will automatically generate unique employee IDs'),
                      value: _settings.isSystemGeneratedIdEnabled,
                      onChanged: (value) {
                        setState(() {
                          _settings = _settings.copyWith(
                            isSystemGeneratedIdEnabled: value,
                          );
                        });
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _idFormatController,
                      label: 'ID Format',
                      hint: 'Format for auto-generated IDs (e.g., DEPTYYMMDD###)',
                    ),


                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveSettings,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Settings'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildTimeField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      validator: validator,
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      keyboardType: TextInputType.number,
      validator: validator,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }

  String? _validateTimeFormat(String? value) {
    if (value == null || value.isEmpty) {
      return 'Time is required';
    }
    
    // Simple time format validation (HH:MM:SS)
    final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$');
    if (!timeRegex.hasMatch(value)) {
      return 'Please enter time in HH:MM:SS format';
    }
    
    return null;
  }

  String? _validateNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Value is required';
    }
    
    final number = int.tryParse(value);
    if (number == null || number < 0) {
      return 'Please enter a valid positive number';
    }
    
    return null;
  }
}