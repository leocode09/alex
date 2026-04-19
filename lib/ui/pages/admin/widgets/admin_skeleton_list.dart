import 'package:flutter/material.dart';

import '../../../design_system/app_theme_extensions.dart';
import '../../../design_system/app_tokens.dart';
import '../../../design_system/widgets/app_panel.dart';

/// Placeholder rows used while a stream is warming up. Pulses slowly
/// via a repeating opacity animation — no extra dependency needed.
class AdminSkeletonList extends StatefulWidget {
  final int rows;
  final double rowHeight;

  const AdminSkeletonList({
    super.key,
    this.rows = 5,
    this.rowHeight = 68,
  });

  @override
  State<AdminSkeletonList> createState() => _AdminSkeletonListState();
}

class _AdminSkeletonListState extends State<AdminSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(begin: 0.35, end: 0.75)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Column(
            children: [
              for (var i = 0; i < widget.rows; i++)
                AppPanel(
                  margin: const EdgeInsets.only(bottom: AppTokens.space1),
                  padding: const EdgeInsets.all(AppTokens.space2),
                  child: SizedBox(
                    height: widget.rowHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 160,
                          height: 12,
                          decoration: BoxDecoration(
                            color: extras.panelAlt,
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusS),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 220,
                          height: 10,
                          decoration: BoxDecoration(
                            color: extras.panelAlt,
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusS),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
