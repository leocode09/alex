import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouteTransitions {
  const AppRouteTransitions._();

  static CustomTransitionPage<void> build({
    required GoRouterState state,
    required Widget child,
  }) {
    final motion = _motionFor(state);

    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: motion.transitionDuration,
      reverseTransitionDuration: motion.reverseTransitionDuration,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
          return child;
        }

        final fade = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0, 0.85, curve: Curves.easeOutCubic),
            reverseCurve: Curves.easeInCubic,
          ),
        );

        final slide = Tween<Offset>(
          begin: motion.beginOffset,
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: motion.curve,
            reverseCurve: Curves.easeInCubic,
          ),
        );

        final scale = Tween<double>(
          begin: motion.beginScale,
          end: 1,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: motion.curve,
            reverseCurve: Curves.easeInCubic,
          ),
        );

        final rotation = Tween<double>(
          begin: motion.beginRotation,
          end: 0,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuart,
            reverseCurve: Curves.easeInQuart,
          ),
        );

        final outgoingFade = Tween<double>(begin: 1, end: 0.94).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.easeOutQuad,
            reverseCurve: Curves.easeOutQuad,
          ),
        );

        return FadeTransition(
          opacity: outgoingFade,
          child: FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(
                scale: scale,
                child: AnimatedBuilder(
                  animation: rotation,
                  child: child,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: rotation.value,
                      child: child,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static _RouteMotion _motionFor(GoRouterState state) {
    final key = state.name ?? state.fullPath ?? state.uri.path;
    final seed = key.hashCode & 0x7fffffff;
    final variant = seed % 6;

    final transitionDuration = Duration(milliseconds: 400 + (seed % 5) * 24);
    final reverseTransitionDuration =
        Duration(milliseconds: 260 + (seed % 4) * 18);

    switch (variant) {
      case 0:
        return _RouteMotion(
          beginOffset: Offset(0, 0.045 + ((seed % 3) * 0.004)),
          beginScale: 0.985,
          beginRotation: 0,
          curve: Curves.easeOutCubic,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: reverseTransitionDuration,
        );
      case 1:
        return _RouteMotion(
          beginOffset: Offset(0.032 + ((seed % 4) * 0.002), 0),
          beginScale: 0.992,
          beginRotation: 0,
          curve: Curves.easeOutQuart,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: reverseTransitionDuration,
        );
      case 2:
        return _RouteMotion(
          beginOffset: Offset(-0.03 - ((seed % 4) * 0.002), 0),
          beginScale: 0.992,
          beginRotation: 0,
          curve: Curves.easeOutQuart,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: reverseTransitionDuration,
        );
      case 3:
        return _RouteMotion(
          beginOffset: Offset(0, 0.02 + ((seed % 3) * 0.003)),
          beginScale: 0.964,
          beginRotation: 0,
          curve: Curves.easeOutBack,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: reverseTransitionDuration,
        );
      case 4:
        return _RouteMotion(
          beginOffset: const Offset(0.018, 0.02),
          beginScale: 0.976,
          beginRotation: 0.008 + ((seed % 3) * 0.001),
          curve: Curves.easeOutCubic,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: reverseTransitionDuration,
        );
      default:
        return _RouteMotion(
          beginOffset: const Offset(-0.015, 0.028),
          beginScale: 0.979,
          beginRotation: -0.008 - ((seed % 3) * 0.001),
          curve: Curves.easeOutCubic,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: reverseTransitionDuration,
        );
    }
  }
}

class _RouteMotion {
  const _RouteMotion({
    required this.beginOffset,
    required this.beginScale,
    required this.beginRotation,
    required this.curve,
    required this.transitionDuration,
    required this.reverseTransitionDuration,
  });

  final Offset beginOffset;
  final double beginScale;
  final double beginRotation;
  final Curve curve;
  final Duration transitionDuration;
  final Duration reverseTransitionDuration;
}
