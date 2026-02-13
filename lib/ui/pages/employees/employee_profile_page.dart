import 'package:flutter/material.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';
import '../../design_system/widgets/app_badge.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_section_header.dart';
import '../../design_system/widgets/app_stat_tile.dart';

class EmployeeProfilePage extends StatelessWidget {
  final String employeeId;

  const EmployeeProfilePage({
    super.key,
    required this.employeeId,
  });

  @override
  Widget build(BuildContext context) {
    final employee = {
      'name': 'Alice Johnson',
      'email': 'alice@example.com',
      'phone': '+250 788 123 456',
      'role': 'Cashier',
      'status': 'Active',
      'joinDate': '2024-01-15',
      'salesCount': 245,
      'totalSales': 4500000,
    };

    return AppPageScaffold(
      title: 'Employee Profile',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () async {
            final allowed = await PinProtection.requirePinIfNeeded(
              context,
              isRequired: () => PinService().isPinRequiredForEditEmployee(),
              title: 'Edit Employee',
              subtitle: 'Enter PIN to edit employee',
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
                    employee['name'].toString().substring(0, 1),
                    style: TextStyle(
                      fontSize: 24,
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
                      Text(employee['name'] as String,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      AppBadge(
                        label: employee['role'] as String,
                        tone: AppBadgeTone.accent,
                      ),
                      const SizedBox(height: 6),
                      Text(employee['email'] as String,
                          style: const TextStyle(color: AppTokens.mutedText)),
                      Text(employee['phone'] as String,
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
                  label: 'Sales',
                  value: '${employee['salesCount']}',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Expanded(
                child: AppStatTile(
                  label: 'Revenue',
                  value: '\$${(employee['totalSales'] as int) ~/ 1000}K',
                  icon: Icons.attach_money_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          const AppSectionHeader(title: 'Performance'),
          AppPanel(
            child: Column(
              children: [
                _buildPerformanceRow(
                    'Total Sales', '${employee['salesCount']}'),
                const Divider(height: 1),
                _buildPerformanceRow(
                    'Total Revenue', '\$${employee['totalSales']}'),
                const Divider(height: 1),
                _buildPerformanceRow('Average/Day',
                    '${(employee['salesCount'] as int) ~/ 30} sales'),
                const Divider(height: 1),
                _buildPerformanceRow('Joined', employee['joinDate'] as String),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTokens.mutedText)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
