import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pin_protection.dart';
import '../../../providers/pin_unlock_provider.dart';
import '../../../providers/time_tamper_provider.dart';
import '../../../services/pin_service.dart';
import '../../../services/time_tamper_service.dart';
import '../../design_system/app_tokens.dart';

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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final glow = 0.08 + (_pulse.value * 0.1);
                  return Container(
                    color: AppTokens.paperAlt,
                    child: CustomPaint(
                      painter: _HazardStripePainter(
                        opacity: glow,
                        color: Theme.of(context).colorScheme.primary,
                      ),
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
                          color: AppTokens.accentSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).colorScheme.primary),
                        ),
                        child: Text(
                          'DANGER',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
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
                                color: AppTokens.accentSoft,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.warning_rounded,
                                size: 70,
                                color: Theme.of(context).colorScheme.primary,
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
                          color: AppTokens.ink,
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
                          color: AppTokens.mutedText,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTokens.paper,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          reason,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTokens.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleVerify,
                          child: Text(_isPinSet ? 'ENTER PIN' : 'SET PIN'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
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
  final Color color;

  _HazardStripePainter({required this.opacity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
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
    return oldDelegate.opacity != opacity || oldDelegate.color != color;
  }
}
