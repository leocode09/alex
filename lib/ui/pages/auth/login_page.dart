import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _pulseController;
  late final AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    )..repeat();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  Future<void> _continueToApp() async {
    final pinService = PinService();
    final requireLoginPin = await pinService.isPinRequiredForLogin();

    if (!mounted) {
      return;
    }

    if (requireLoginPin) {
      context.go('/pin-entry');
      return;
    }

    final requireDashboardPin = await pinService.isPinRequiredForDashboard();
    if (!mounted) {
      return;
    }

    if (requireDashboardPin) {
      final verified = await PinProtection.requirePin(
        context,
        title: 'Money Access',
        subtitle: 'Enter PIN to view money accounts',
      );
      if (!verified) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    context.go('/money');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final extras = context.appExtras;
    final titleReveal = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.36, 0.78, curve: Curves.easeOutCubic),
    );
    final panelReveal = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.62, curve: Curves.easeOutBack),
    );
    final buttonReveal = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.68, 1.0, curve: Curves.easeOutCubic),
    );

    return AppPageScaffold(
      includeSafeArea: true,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(child: _buildBackground(scheme, extras)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.space4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: FadeTransition(
                  opacity: panelReveal,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.84, end: 1).animate(
                      panelReveal,
                    ),
                    child: AppPanel(
                      emphasized: true,
                      outlinedStrong: true,
                      color: extras.panel.withValues(alpha: 0.94),
                      padding: const EdgeInsets.all(AppTokens.space5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatusPill(scheme, extras),
                          const SizedBox(height: AppTokens.space4),
                          _buildAnimatedIcon(scheme),
                          const SizedBox(height: AppTokens.space4),
                          FadeTransition(
                            opacity: titleReveal,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.9, end: 1).animate(
                                titleReveal,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'ALEX',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                        ),
                                  ),
                                  const SizedBox(height: AppTokens.space1),
                                  Text(
                                    'Retail operating console',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: extras.muted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTokens.space4),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: AppTokens.space2,
                            runSpacing: AppTokens.space2,
                            children: [
                              _buildFeaturePill(
                                icon: Icons.payments_outlined,
                                label: 'FAST CHECKOUT',
                                start: 0.46,
                                end: 0.72,
                              ),
                              _buildFeaturePill(
                                icon: Icons.inventory_2_outlined,
                                label: 'SMART STOCK',
                                start: 0.56,
                                end: 0.82,
                              ),
                              _buildFeaturePill(
                                icon: Icons.sync_rounded,
                                label: 'LIVE SYNC',
                                start: 0.66,
                                end: 0.92,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTokens.space5),
                          FadeTransition(
                            opacity: buttonReveal,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.92, end: 1).animate(
                                buttonReveal,
                              ),
                              child: _buildAnimatedButton(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(ColorScheme scheme, AppThemeExtras extras) {
    return AnimatedBuilder(
      animation: Listenable.merge([_orbitController, _pulseController]),
      builder: (context, child) {
        final orbit = _orbitController.value * 2 * math.pi;
        final pulse =
            1 + (math.sin(_pulseController.value * 2 * math.pi) * 0.05);

        return Stack(
          children: [
            Positioned(
              left: -120 + (math.sin(orbit) * 26),
              top: -70 + (math.cos(orbit * 0.8) * 24),
              child: Transform.scale(
                scale: pulse,
                child: _ambientOrb(
                  size: 280,
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderColor: scheme.primary.withValues(alpha: 0.24),
                ),
              ),
            ),
            Positioned(
              right: -100 + (math.cos(orbit * 0.7) * 20),
              bottom: -90 + (math.sin(orbit) * 22),
              child: Transform.scale(
                scale: 1 - ((pulse - 1) * 0.8),
                child: _ambientOrb(
                  size: 250,
                  color: extras.accentSoft.withValues(alpha: 0.2),
                  borderColor: scheme.primary.withValues(alpha: 0.16),
                ),
              ),
            ),
            Positioned(
              left: 30 + (math.sin(orbit * 1.4) * 14),
              bottom: 110 + (math.cos(orbit * 1.1) * 16),
              child: _ambientOrb(
                size: 120,
                color: extras.panel.withValues(alpha: 0.55),
                borderColor: extras.borderStrong.withValues(alpha: 0.55),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _ambientOrb({
    required double size,
    required Color color,
    required Color borderColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: borderColor, width: AppTokens.border),
      ),
    );
  }

  Widget _buildStatusPill(ColorScheme scheme, AppThemeExtras extras) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final dotScale = 0.9 + (_pulseController.value * 0.45);
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space3,
            vertical: AppTokens.space1,
          ),
          decoration: BoxDecoration(
            color: extras.panel,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: extras.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: dotScale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space1),
              Text(
                'SYSTEM READY',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedIcon(ColorScheme scheme) {
    final reveal = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.14, 0.58, curve: Curves.easeOutBack),
    );

    return ScaleTransition(
      scale: Tween<double>(begin: 0.72, end: 1).animate(reveal),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse =
              1 + (math.sin(_pulseController.value * 2 * math.pi) * 0.08);
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.08),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.32),
                      width: AppTokens.borderStrong,
                    ),
                  ),
                ),
              ),
              Container(
                width: 98,
                height: 98,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.48),
                    width: AppTokens.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.point_of_sale_rounded,
                  size: 52,
                  color: scheme.primary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String label,
    required double start,
    required double end,
  }) {
    final reveal = CurvedAnimation(
      parent: _entryController,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );

    return FadeTransition(
      opacity: reveal,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1).animate(reveal),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space2,
            vertical: AppTokens.space1,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: context.appExtras.borderStrong),
            color: context.appExtras.panel,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse =
            1 + (math.sin(_pulseController.value * 2 * math.pi) * 0.012);
        return Transform.scale(scale: pulse, child: child);
      },
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _continueToApp,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusM + 2),
            ),
          ),
          child: const Text('Continue'),
        ),
      ),
    );
  }
}
