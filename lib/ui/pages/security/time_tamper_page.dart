import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pin_protection.dart';
import '../../../providers/pin_unlock_provider.dart';
import '../../../providers/time_tamper_provider.dart';
import '../../../services/pin_service.dart';
import '../../../services/time_tamper_service.dart';

class TimeTamperPage extends ConsumerStatefulWidget {
  const TimeTamperPage({super.key});

  @override
  ConsumerState<TimeTamperPage> createState() => _TimeTamperPageState();
}

class _TimeTamperPageState extends ConsumerState<TimeTamperPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;
  final TimeTamperService _service = TimeTamperService();
  bool _isPinSet = true;
  bool _loadingPin = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _loadPinStatus();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPinStatus() async {
    final isSet = await PinService().isPinSet();
    if (!mounted) {
      return;
    }
    setState(() {
      _isPinSet = isSet;
      _loadingPin = false;
    });
  }

  Future<void> _handleVerify() async {
    if (_loadingPin) {
      return;
    }
    if (!_isPinSet) {
      if (mounted) {
        context.go('/pin-setup');
      }
      return;
    }
    final verified = await PinProtection.requirePin(
      context,
      title: 'Security Verification',
      subtitle: 'Enter PIN to unlock after time change',
    );
    if (!verified || !mounted) {
      return;
    }
    await _service.clearTamper();
    ref.read(timeTamperProvider.notifier).state = null;
    ref.read(pinUnlockedProvider.notifier).state = true;
    context.go('/dashboard');
  }

  Future<void> _openSettings() async {
    await _service.openDateTimeSettings();
  }

  @override
  Widget build(BuildContext context) {
    final tamper = ref.watch(timeTamperProvider);
    final reason = tamper?.reason ?? 'Device time was modified.';

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final glow = 0.15 + (_pulse.value * 0.25);
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0A0A0A),
                          const Color(0xFF2B0000),
                          const Color(0xFF6B0000).withOpacity(0.9),
                        ],
                      ),
                    ),
                    child: CustomPaint(
                      painter: _HazardStripePainter(opacity: glow),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2D2D),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF2D2D).withOpacity(0.4),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Text(
                          'DANGER',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) {
                          final scale = 0.95 + (_pulse.value * 0.08);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1A0000),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF2D2D)
                                        .withOpacity(0.5),
                                    blurRadius: 30,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.warning_rounded,
                                size: 70,
                                color: Color(0xFFFF2D2D),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'TIME CHANGE DETECTED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Access is locked until you verify your identity.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFC1C1),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A0000),
                          border: Border.all(
                            color: const Color(0xFFFF2D2D),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          reason,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFF9E9E),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF2D2D),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          onPressed: _handleVerify,
                          child: Text(_isPinSet ? 'ENTER PIN' : 'SET PIN'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF8080),
                            side: const BorderSide(
                              color: Color(0xFFFF2D2D),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _openSettings,
                          child: const Text('OPEN DATE & TIME SETTINGS'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HazardStripePainter extends CustomPainter {
  final double opacity;

  _HazardStripePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF2D2D).withOpacity(opacity * 0.2)
      ..strokeWidth = 14;

    const gap = 48.0;
    for (double x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HazardStripePainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}
