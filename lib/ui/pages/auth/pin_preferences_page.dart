import 'package:flutter/material.dart';
import '../../../services/pin_service.dart';

class PinPreferencesPage extends StatefulWidget {
  const PinPreferencesPage({super.key});

  @override
  State<PinPreferencesPage> createState() => _PinPreferencesPageState();
}

class _PinPreferencesPageState extends State<PinPreferencesPage> {
  final PinService _pinService = PinService();
  
  bool _requireOnLogin = true;
  bool _requireOnAddProduct = false;
  bool _requireOnEditProduct = false;
  bool _requireOnDeleteProduct = false;
  bool _requireOnSettings = false;
  bool _requireOnReports = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await _pinService.getPinPreferences();
    setState(() {
      _requireOnLogin = prefs['login'] ?? true;
      _requireOnAddProduct = prefs['addProduct'] ?? false;
      _requireOnEditProduct = prefs['editProduct'] ?? false;
      _requireOnDeleteProduct = prefs['deleteProduct'] ?? false;
      _requireOnSettings = prefs['settings'] ?? false;
      _requireOnReports = prefs['reports'] ?? false;
      _isLoading = false;
    });
  }

  Future<void> _savePreferences() async {
    await _pinService.updatePinPreferences(
      requireOnLogin: _requireOnLogin,
      requireOnAddProduct: _requireOnAddProduct,
      requireOnEditProduct: _requireOnEditProduct,
      requireOnDeleteProduct: _requireOnDeleteProduct,
      requireOnSettings: _requireOnSettings,
      requireOnReports: _requireOnReports,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN preferences updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('PIN Preferences', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.security,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Choose where to require PIN',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select which actions should require PIN verification for security',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildPreferenceSwitch(
                            icon: Icons.login,
                            title: 'Login',
                            subtitle: 'Require PIN every time you log in',
                            value: _requireOnLogin,
                            onChanged: (value) => setState(() => _requireOnLogin = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.add_box_outlined,
                            title: 'Add Products',
                            subtitle: 'Require PIN when adding new products',
                            value: _requireOnAddProduct,
                            onChanged: (value) => setState(() => _requireOnAddProduct = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.edit_outlined,
                            title: 'Edit Products',
                            subtitle: 'Require PIN when editing existing products',
                            value: _requireOnEditProduct,
                            onChanged: (value) => setState(() => _requireOnEditProduct = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.delete_outlined,
                            title: 'Delete Products',
                            subtitle: 'Require PIN when deleting products',
                            value: _requireOnDeleteProduct,
                            onChanged: (value) => setState(() => _requireOnDeleteProduct = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.settings_outlined,
                            title: 'Settings',
                            subtitle: 'Require PIN to access settings',
                            value: _requireOnSettings,
                            onChanged: (value) => setState(() => _requireOnSettings = value),
                          ),
                          _buildPreferenceSwitch(
                            icon: Icons.bar_chart_outlined,
                            title: 'Reports',
                            subtitle: 'Require PIN to view reports',
                            value: _requireOnReports,
                            onChanged: (value) => setState(() => _requireOnReports = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _savePreferences,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Preferences',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPreferenceSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SwitchListTile(
          secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
