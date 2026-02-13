import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';
import '../../design_system/widgets/app_badge.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

class StoresPage extends StatelessWidget {
  const StoresPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stores = [
      {
        'id': '1',
        'name': 'Store A (Main)',
        'location': 'Kigali Downtown',
        'status': 'Active'
      },
      {
        'id': '2',
        'name': 'Store B (Kigali)',
        'location': 'Kimironko',
        'status': 'Active'
      },
    ];

    return AppPageScaffold(
      title: 'Stores',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (await PinProtection.requirePinIfNeeded(
            context,
            isRequired: () => PinService().isPinRequiredForAddStore(),
            title: 'Add Store',
            subtitle: 'Enter PIN to add a store',
          )) {
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add store feature')),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
      child: ListView.separated(
        itemCount: stores.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space2),
        itemBuilder: (context, index) {
          final store = stores[index];
          return AppPanel(
            child: ListTile(
              onTap: () async {
                if (await PinProtection.requirePinIfNeeded(
                  context,
                  isRequired: () => PinService().isPinRequiredForViewStores(),
                  title: 'Store Details',
                  subtitle: 'Enter PIN to view store details',
                )) {
                  if (!context.mounted) {
                    return;
                  }
                  context.push('/stores/${store['id']}');
                }
              },
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTokens.paperAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTokens.line),
                ),
                child: Icon(Icons.store_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 20),
              ),
              title: Text(store['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(store['location'] as String,
                  style: const TextStyle(
                      color: AppTokens.mutedText, fontSize: 12)),
              trailing: AppBadge(
                label: store['status'] as String,
                tone: AppBadgeTone.success,
              ),
            ),
          );
        },
      ),
    );
  }
}
