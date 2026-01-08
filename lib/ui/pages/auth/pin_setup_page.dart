import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/pin_service.dart';

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  final PinService _pinService = PinService();
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _showPreferences = false;
  List<String> _shuffledNumbers = [];
  
  // PIN requirement preferences
  bool _requireOnLogin = true;
  bool _requireOnAddProduct = false;
  bool _requireOnEditProduct = false;
  bool _requireOnDeleteProduct = false;
  bool _requireOnSettings = false;
  bool _requireOnReports = false;

  @override
  void initState() {
    super.initState();
    _shuffleNumbers();
  }

  void _shuffleNumbers() {
    _shuffledNumbers = List.generate(10, (index) => index.toString());
    _shuffledNumbers.shuffle(Random());
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (!_isConfirming) {
        if (_pin.length < 4) {
          _pin += number;
          if (_pin.length == 4) {
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() {
                _isConfirming = true;
                _shuffleNumbers();
              });
            });
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += number;
          if (_confirmPin.length == 4) {
            _verifyPins();
          }
        }
      }
    });
  }

  void _onDeletePressed() {
    setState(() {
      if (!_isConfirming) {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      }
    });
  }

  Future<void> _verifyPins() async {
    if (_pin == _confirmPin) {
      setState(() {
        _showPreferences = true;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PINs do not match. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _pin = '';
          _confirmPin = '';
          _isConfirming = false;
          _shuffleNumbers();
        });
      }
    }
  }

  Future<void> _savePinWithPreferences() async {
    await _pinService.setPin(
      _pin,
      requireOnLogin: _requireOnLogin,
      requireOnAddProduct: _requireOnAddProduct,
      requireOnEditProduct: _requireOnEditProduct,
      requireOnDeleteProduct: _requireOnDeleteProduct,
      requireOnSettings: _requireOnSettings,
      requireOnReports: _requireOnReports,
    );
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showPreferences) {
      return _buildPreferencesScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                _isConfirming ? 'Confirm PIN' : 'Create PIN',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Enter your PIN again to confirm'
                    : 'Create a 4-digit PIN to secure your app',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isConfirming
                                ? index < _confirmPin.length
                                : index < _pin.length)
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _buildKeypad(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('PIN Settings', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
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
                  onPressed: _savePinWithPreferences,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Complete Setup',
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

  Widget _buildKeypad() {
    return Column(
      children: [
        for (int i = 0; i < 3; i++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int j = 0; j < 3; j++)
                _buildKeypadButton(_shuffledNumbers[i * 3 + j]),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80, height: 80), // Empty space
            _buildKeypadButton(_shuffledNumbers[9]),
            _buildKeypadButton('⌫', isDelete: true),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String value, {bool isDelete = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () {
          if (isDelete) {
            _onDeletePressed();
          } else {
            _onNumberPressed(value);
          }
        },
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[100],
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isDelete ? 28 : 24,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
