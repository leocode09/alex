import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// App-wide page transition.
///
/// Design goals:
///   * **No ghosting.** The incoming page is never made translucent, so two
///     full pages are never cross-dissolved on top of each other. The old
///     behaviour faded a translucent page in (opacity 0→1) over the previous
///     page that only faded to 0.94 — mid-transition you saw *both* pages at
///     once (e.g. the Reports cards bleeding through the Sales grid).
///   * **Fast & consistent.** A single short slide + slight scale, instead of
///     the previous per-route random fade/slide/scale/rotate stack.
class AppRouteTransitions {
  const AppRouteTransitions._();

  /// Kept short on purpose — snappy navigation. (Was 400–496 ms.)
  static const Duration _forward = Duration(milliseconds: 200);
  static const Duration _reverse = Duration(milliseconds: 150);

  static CustomTransitionPage<void> build({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      // opaque (the default) means the page below is not painted once the
      // transition settles — combined with the opaque incoming page above,
      // pages never visually stack.
      transitionDuration: _forward,
      reverseTransitionDuration: _reverse,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
          return child;
        }

        // Incoming page (driven by `animation`): a small upward settle plus a
        // barely-there scale. Crucially there is NO opacity tween here, so the
        // page stays fully opaque and the previous page can't show through it.
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final slide = Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved);

        final scale = Tween<double>(begin: 0.99, end: 1).animate(curved);

        return SlideTransition(
          position: slide,
          child: ScaleTransition(
            scale: scale,
            child: child,
          ),
        );
      },
    );
  }
}
