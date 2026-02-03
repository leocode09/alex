import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart,
                size: 100,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              Text(
                'POS System',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 48),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final pinService = PinService();
                      final requireLoginPin =
                          await pinService.isPinRequiredForLogin();

                      if (requireLoginPin) {
                        context.go('/pin-entry');
                        return;
                      }

                      final requireDashboardPin =
                          await pinService.isPinRequiredForDashboard();
                      if (requireDashboardPin) {
                        final verified = await PinProtection.requirePin(
                          context,
                          title: 'Dashboard Access',
                          subtitle: 'Enter PIN to view dashboard',
                        );
                        if (!verified) {
                          return;
                        }
                      }

                      context.go('/dashboard');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
