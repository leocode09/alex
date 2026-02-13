import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/pin_service.dart';

class PinEntryPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool canGoBack;
  final Future<void> Function()? onSuccess;
  final bool popOnSuccess;

  const PinEntryPage({
    super.key,
    this.title = 'Enter PIN',
    this.subtitle = 'Enter your 4-digit PIN',
    this.canGoBack = true,
    this.onSuccess,
    this.popOnSuccess = true,
  });

  @override
  State<PinEntryPage> createState() => _PinEntryPageState();
}

class _PinEntryPageState extends State<PinEntryPage> {
  final PinService _pinService = PinService();
  String _pin = '';
  List<String> _shuffledNumbers = [];
  bool _isError = false;

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
    if (_pin.length < 4) {
      setState(() {
        _pin += number;
        _isError = false;
        if (_pin.length == 4) {
          _verifyPin();
        }
      });
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _isError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final isValid = await _pinService.verifyPin(_pin);
    if (isValid) {
      if (widget.onSuccess != null) {
        await widget.onSuccess!();
      }
      if (mounted) {
        if (widget.popOnSuccess) {
          Navigator.of(context).pop(true);
        }
      }
    } else {
      setState(() {
        _isError = true;
        _pin = '';
      });
      _shuffleNumbers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect PIN. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.canGoBack
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
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
                color: _isError ? Colors.red : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _isError ? Colors.red : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < _pin.length
                            ? (_isError ? Colors.red : Theme.of(context).colorScheme.primary)
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
            _buildKeypadButton('DEL', isDelete: true),
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
