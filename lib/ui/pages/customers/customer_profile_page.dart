import 'package:flutter/material.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_section_header.dart';
import '../../design_system/widgets/app_stat_tile.dart';

class CustomerProfilePage extends StatelessWidget {
  final String customerId;

  const CustomerProfilePage({
    super.key,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context) {
    final customer = {
      'name': 'John Doe',
      'phone': '+250 788 123 456',
      'email': 'john.doe@example.com',
      'totalPurchases': 12,
      'totalSpent': 45000,
      'joinDate': '2024-01-15',
    };

    final recentPurchases = [
      {'date': '2024-12-10', 'amount': 5000, 'items': 3},
      {'date': '2024-12-08', 'amount': 3500, 'items': 2},
      {'date': '2024-12-05', 'amount': 8000, 'items': 5},
    ];

    return AppPageScaffold(
      title: 'Customer Profile',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () async {
            final allowed = await PinProtection.requirePinIfNeeded(
              context,
              isRequired: () => PinService().isPinRequiredForEditCustomer(),
              title: 'Edit Customer',
              subtitle: 'Enter PIN to edit customer',
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
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTokens.paper,
                  child: Text(
                    customer['name'].toString().substring(0, 1),
                    style: TextStyle(
                      fontSize: 22,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer['name'] as String,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(customer['phone'] as String,
                          style: const TextStyle(color: AppTokens.mutedText)),
                      Text(customer['email'] as String,
                          style: const TextStyle(color: AppTokens.mutedText)),
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
                  label: 'Purchases',
                  value: '${customer['totalPurchases']}',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Expanded(
                child: AppStatTile(
                  label: 'Spent',
                  value: '\$${customer['totalSpent']}',
                  icon: Icons.attach_money_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          const AppSectionHeader(title: 'Recent Purchases'),
          AppPanel(
            child: Column(
              children: recentPurchases.asMap().entries.map((entry) {
                final index = entry.key;
                final purchase = entry.value;
                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('\$${purchase['amount']}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${purchase['items']} items',
                          style: const TextStyle(
                              color: AppTokens.mutedText, fontSize: 12)),
                      trailing: Text(purchase['date'] as String,
                          style: const TextStyle(
                              color: AppTokens.mutedText, fontSize: 12)),
                    ),
                    if (index < recentPurchases.length - 1)
                      const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
