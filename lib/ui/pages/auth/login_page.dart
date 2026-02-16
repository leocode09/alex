import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPageScaffold(
      includeSafeArea: true,
      padding: const EdgeInsets.all(AppTokens.space4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AppPanel(
            emphasized: true,
            padding: const EdgeInsets.all(AppTokens.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.point_of_sale_outlined,
                  size: 84,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppTokens.space4),
                Text(
                  'ALEX',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppTokens.space1),
                Text(
                  'Retail operating console',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTokens.mutedText,
                      ),
                ),
                const SizedBox(height: AppTokens.space5),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final pinService = PinService();
                      final requireLoginPin =
                          await pinService.isPinRequiredForLogin();

                      if (!context.mounted) {
                        return;
                      }

                      if (requireLoginPin) {
                        context.go('/pin-entry');
                        return;
                      }

                      final requireDashboardPin =
                          await pinService.isPinRequiredForDashboard();
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

                      if (!context.mounted) {
                        return;
                      }

                      context.go('/money');
                    },
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
