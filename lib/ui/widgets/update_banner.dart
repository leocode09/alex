import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/update_service.dart';
import '../design_system/app_theme_extensions.dart';
import '../design_system/app_tokens.dart';

/// Slim app-wide strip shown once a newer build has been downloaded and
/// verified by [UpdateService]. The check and download are silent; this is
/// the one visible moment — offering to install now.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return ValueListenableBuilder<ReadyUpdate?>(
      valueListenable: UpdateService.instance.ready,
      builder: (context, update, _) {
        final Widget strip = update == null
            ? const SizedBox.shrink(key: ValueKey('update-none'))
            : _Strip(key: const ValueKey('update-ready'), update: update);

        // Overlay (not a dialog): works on every gate including account
        // login, where a showDialog from MaterialApp.builder would fail
        // because that context sits above the Navigator.
        return IgnorePointer(
          ignoring: update == null,
          child: AnimatedSize(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child: strip,
            ),
          ),
        );
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({super.key, required this.update});

  final ReadyUpdate update;

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final topInset = MediaQuery.of(context).viewPadding.top;

    return Material(
      color: extras.success,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        minimum: EdgeInsets.only(
          top: topInset > 0 ? AppTokens.space1 : AppTokens.space2,
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: AppTokens.space2,
            left: AppTokens.space3,
            right: AppTokens.space3,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update_alt_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: AppTokens.space2),
              Flexible(
                child: Text(
                  'ALEX ${update.version} is ready.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              TextButton(
                onPressed: () => unawaited(UpdateService.instance.applyNow()),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space3,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: Colors.white54),
                ),
                child: const Text(
                  'Install',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
