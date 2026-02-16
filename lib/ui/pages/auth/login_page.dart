import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';

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
    final isMobile = MediaQuery.sizeOf(context).width < 600;
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
                constraints: BoxConstraints(maxWidth: isMobile ? 440 : 560),
                child: FadeTransition(
                  opacity: panelReveal,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.84, end: 1).animate(
                      panelReveal,
                    ),
                    child: _buildClayCard(
                      scheme: scheme,
                      extras: extras,
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
                                        .displaySmall
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
                                        .bodyLarge
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
      animation: _orbitController,
      builder: (context, child) {
        return CustomPaint(
          painter: _TechBackdropPainter(
            progress: _orbitController.value,
            plateColor: Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.05),
              extras.panelAlt,
            ),
            traceColor: scheme.primary.withValues(alpha: 0.2),
            traceSoftColor: scheme.primary.withValues(alpha: 0.1),
            packetColor: scheme.primary.withValues(alpha: 0.68),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  Widget _buildClayCard({
    required ColorScheme scheme,
    required AppThemeExtras extras,
    required Widget child,
  }) {
    final topColor =
        Color.lerp(extras.panelAlt, extras.panel, 0.55) ?? extras.panel;
    final depthColor = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.14),
      extras.panelAlt,
    );

    return Stack(
      children: [
        Positioned.fill(
          top: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: depthColor,
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppTokens.space5),
          decoration: BoxDecoration(
            color: topColor.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(30),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildClayCapsule({
    required Widget child,
    required Color topColor,
    required Color depthColor,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: AppTokens.space3,
      vertical: AppTokens.space1,
    ),
  }) {
    return Stack(
      children: [
        Positioned.fill(
          top: 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: depthColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Container(
          padding: padding,
          decoration: BoxDecoration(
            color: topColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildStatusPill(ColorScheme scheme, AppThemeExtras extras) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final dotScale = 0.9 + (_pulseController.value * 0.45);
        return _buildClayCapsule(
          topColor: Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.06),
            extras.panel,
          ),
          depthColor: Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.12),
            extras.panelAlt,
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
        animation: Listenable.merge([_pulseController, _orbitController]),
        builder: (context, child) {
          final pulse =
              1 + (math.sin(_pulseController.value * 2 * math.pi) * 0.035);
          return Transform.scale(
            scale: pulse,
            child: SizedBox(
              width: 172,
              height: 172,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(172, 172),
                    painter: _TechEmblemPainter(
                      progress: _orbitController.value,
                      traceColor: scheme.primary.withValues(alpha: 0.34),
                      traceSoftColor: scheme.primary.withValues(alpha: 0.14),
                      packetColor: scheme.primary.withValues(alpha: 0.78),
                    ),
                  ),
                  Transform.scale(
                    scale: 1 +
                        (math.sin(_pulseController.value * 2 * math.pi) * 0.02),
                    child: Container(
                      width: 94,
                      height: 94,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.2),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.point_of_sale_rounded,
                        size: 52,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
        child: _buildClayCapsule(
          topColor: Color.alphaBlend(
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            context.appExtras.panel,
          ),
          depthColor: Color.alphaBlend(
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            context.appExtras.panelAlt,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space2,
            vertical: AppTokens.space1,
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
        height: 58,
        child: Stack(
          children: [
            Positioned.fill(
              top: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppTokens.radiusL),
                ),
              ),
            ),
            Positioned.fill(
              child: ElevatedButton(
                onPressed: _continueToApp,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusL),
                  ),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechBackdropPainter extends CustomPainter {
  const _TechBackdropPainter({
    required this.progress,
    required this.plateColor,
    required this.traceColor,
    required this.traceSoftColor,
    required this.packetColor,
  });

  final double progress;
  final Color plateColor;
  final Color traceColor;
  final Color traceSoftColor;
  final Color packetColor;

  @override
  void paint(Canvas canvas, Size size) {
    final platePaint = Paint()
      ..color = plateColor
      ..style = PaintingStyle.fill;
    final strongTracePaint = Paint()
      ..color = traceColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final softTracePaint = Paint()
      ..color = traceSoftColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final packetPaint = Paint()
      ..color = packetColor
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final nodePaint = Paint()
      ..color = packetColor.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-56, size.height * 0.08, size.width * 0.48, 124),
        const Radius.circular(64),
      ),
      platePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            size.width * 0.64, size.height * 0.78, size.width * 0.52, 180),
        const Radius.circular(90),
      ),
      platePaint,
    );

    final traces = <List<Offset>>[
      [
        Offset(-24, size.height * 0.17),
        Offset(size.width * 0.18, size.height * 0.17),
        Offset(size.width * 0.18, size.height * 0.29),
        Offset(size.width * 0.56, size.height * 0.29),
        Offset(size.width * 0.56, size.height * 0.15),
        Offset(size.width + 24, size.height * 0.15),
      ],
      [
        Offset(-16, size.height * 0.58),
        Offset(size.width * 0.14, size.height * 0.58),
        Offset(size.width * 0.14, size.height * 0.7),
        Offset(size.width * 0.42, size.height * 0.7),
        Offset(size.width * 0.42, size.height * 0.85),
        Offset(size.width * 0.88, size.height * 0.85),
        Offset(size.width + 20, size.height * 0.85),
      ],
      [
        Offset(size.width * 0.76, -20),
        Offset(size.width * 0.76, size.height * 0.22),
        Offset(size.width * 0.62, size.height * 0.22),
        Offset(size.width * 0.62, size.height * 0.46),
        Offset(size.width * 0.86, size.height * 0.46),
        Offset(size.width * 0.86, size.height * 0.64),
      ],
      [
        Offset(size.width * 0.08, size.height * 0.36),
        Offset(size.width * 0.3, size.height * 0.36),
        Offset(size.width * 0.3, size.height * 0.48),
        Offset(size.width * 0.5, size.height * 0.48),
      ],
    ];

    for (var i = 0; i < traces.length; i++) {
      final path = _polylinePath(traces[i]);
      canvas.drawPath(path, i.isEven ? strongTracePaint : softTracePaint);

      _drawPacket(
        canvas: canvas,
        path: path,
        packetPaint: packetPaint,
        nodePaint: nodePaint,
        t: (progress + (i * 0.19)) % 1,
      );

      for (final node in traces[i].skip(1).take(traces[i].length - 2)) {
        final shimmer = 1 +
            (math.sin((progress * 2 * math.pi) + node.dx * 0.01 + (i * 0.9)) *
                0.12);
        canvas.drawCircle(node, 2.2 * shimmer, nodePaint);
      }
    }
  }

  Path _polylinePath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }

  void _drawPacket({
    required Canvas canvas,
    required Path path,
    required Paint packetPaint,
    required Paint nodePaint,
    required double t,
  }) {
    for (final metric in path.computeMetrics()) {
      if (metric.length <= 0) {
        continue;
      }
      final segmentLength = math.min(metric.length * 0.22, 84.0);
      final start = (metric.length * t) % metric.length;
      final end = start + segmentLength;
      if (end <= metric.length) {
        canvas.drawPath(metric.extractPath(start, end), packetPaint);
      } else {
        canvas.drawPath(metric.extractPath(start, metric.length), packetPaint);
        canvas.drawPath(
            metric.extractPath(0, end - metric.length), packetPaint);
      }

      final markerOffset = (start + (segmentLength * 0.6)) % metric.length;
      final marker = metric.getTangentForOffset(markerOffset);
      if (marker != null) {
        canvas.drawCircle(marker.position, 3, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TechBackdropPainter other) {
    return other.progress != progress ||
        other.plateColor != plateColor ||
        other.traceColor != traceColor ||
        other.traceSoftColor != traceSoftColor ||
        other.packetColor != packetColor;
  }
}

class _TechEmblemPainter extends CustomPainter {
  const _TechEmblemPainter({
    required this.progress,
    required this.traceColor,
    required this.traceSoftColor,
    required this.packetColor,
  });

  final double progress;
  final Color traceColor;
  final Color traceSoftColor;
  final Color packetColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strongTracePaint = Paint()
      ..color = traceColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final softTracePaint = Paint()
      ..color = traceSoftColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final packetPaint = Paint()
      ..color = packetColor
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final nodePaint = Paint()
      ..color = packetColor.withValues(alpha: 0.84)
      ..style = PaintingStyle.fill;

    final outerFrame = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: size.width * 0.82,
            height: size.height * 0.82,
          ),
          const Radius.circular(28),
        ),
      );
    canvas.drawPath(outerFrame, softTracePaint);

    final traces = <List<Offset>>[
      [
        Offset(size.width * 0.05, center.dy),
        Offset(size.width * 0.32, center.dy),
        Offset(size.width * 0.32, size.height * 0.34),
        Offset(size.width * 0.44, size.height * 0.34),
      ],
      [
        Offset(size.width * 0.95, center.dy),
        Offset(size.width * 0.68, center.dy),
        Offset(size.width * 0.68, size.height * 0.66),
        Offset(size.width * 0.56, size.height * 0.66),
      ],
      [
        Offset(center.dx, size.height * 0.05),
        Offset(center.dx, size.height * 0.3),
        Offset(size.width * 0.6, size.height * 0.3),
      ],
      [
        Offset(center.dx, size.height * 0.95),
        Offset(center.dx, size.height * 0.7),
        Offset(size.width * 0.4, size.height * 0.7),
      ],
    ];

    for (var i = 0; i < traces.length; i++) {
      final path = _polylinePath(traces[i]);
      canvas.drawPath(path, i.isEven ? strongTracePaint : softTracePaint);
      _drawPacket(
        canvas: canvas,
        path: path,
        packetPaint: packetPaint,
        nodePaint: nodePaint,
        t: (progress + (i * 0.27)) % 1,
      );
      for (final node in traces[i].skip(1)) {
        canvas.drawCircle(node, 2.4, nodePaint);
      }
    }

    _drawPacket(
      canvas: canvas,
      path: outerFrame,
      packetPaint: packetPaint,
      nodePaint: nodePaint,
      t: (progress * 1.2) % 1,
    );
  }

  Path _polylinePath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }

  void _drawPacket({
    required Canvas canvas,
    required Path path,
    required Paint packetPaint,
    required Paint nodePaint,
    required double t,
  }) {
    for (final metric in path.computeMetrics()) {
      if (metric.length <= 0) {
        continue;
      }
      final segmentLength = math.min(metric.length * 0.16, 52.0);
      final start = (metric.length * t) % metric.length;
      final end = start + segmentLength;
      if (end <= metric.length) {
        canvas.drawPath(metric.extractPath(start, end), packetPaint);
      } else {
        canvas.drawPath(metric.extractPath(start, metric.length), packetPaint);
        canvas.drawPath(
            metric.extractPath(0, end - metric.length), packetPaint);
      }

      final markerOffset = (start + (segmentLength * 0.58)) % metric.length;
      final marker = metric.getTangentForOffset(markerOffset);
      if (marker != null) {
        canvas.drawCircle(marker.position, 2.4, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TechEmblemPainter other) {
    return other.progress != progress ||
        other.traceColor != traceColor ||
        other.traceSoftColor != traceSoftColor ||
        other.packetColor != packetColor;
  }
}
