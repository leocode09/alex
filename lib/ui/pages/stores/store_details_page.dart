import 'package:flutter/material.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';
import '../../design_system/app_badge.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_section_header.dart';
import '../../design_system/widgets/app_stat_tile.dart';

class StoreDetailsPage extends StatelessWidget {
  final String storeId;

  const StoreDetailsPage({
    super.key,
    required this.storeId,
  });

  @override
  Widget build(BuildContext context) {
    final store = {
      'name': 'Store A (Main)',
      'location': 'Kigali Downtown',
      'address': '123 Main Street, Kigali',
      'phone': '+250 788 123 456',
      'manager': 'Bob Smith',
      'employees': 5,
      'todaySales': 120000,
      'status': 'Active',
    };

    return AppPageScaffold(
      title: 'Store Details',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () async {
            final allowed = await PinProtection.requirePinIfNeeded(
              context,
              isRequired: () => PinService().isPinRequiredForEditStore(),
              title: 'Edit Store',
              subtitle: 'Enter PIN to edit store',
            );
            if (!allowed) {
              return;
            }
          },
        ),
        const SizedBox(width: 6),
      ],
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPanel(
            emphasized: true,
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTokens.paper,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTokens.line),
                  ),
                  child: const Icon(Icons.store_outlined, color: AppTokens.mutedText),
                ),
                const SizedBox(width: AppTokens.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store['name'] as String,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      AppBadge(
                        label: store['status'] as String,
                        tone: AppBadgeTone.success,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          Row(
            children: [
              Expanded(
                child: AppStatTile(
                  label: 'Sales Today',
                  value: '${(store['todaySales'] as int) ~/ 1000}K',
                  icon: Icons.attach_money_outlined,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Expanded(
                child: AppStatTile(
                  label: 'Employees',
                  value: '${store['employees']}',
                  icon: Icons.people_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          const AppSectionHeader(title: 'Information'),
          AppPanel(
            child: Column(
              children: [
                _buildDetailRow('Location', store['location'] as String),
                _buildDetailRow('Address', store['address'] as String),
                _buildDetailRow('Phone', store['phone'] as String),
                _buildDetailRow('Manager', store['manager'] as String, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          const AppSectionHeader(title: 'Actions'),
          AppPanel(
            child: Column(
              children: [
                _buildActionTile(context, 'View Inventory', Icons.inventory_2_outlined),
                _buildActionTile(context, 'View Employees', Icons.people_outline),
                _buildActionTile(context, 'Sales History', Icons.history, isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: const TextStyle(color: AppTokens.mutedText)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildActionTile(BuildContext context, String title, IconData icon, {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}
