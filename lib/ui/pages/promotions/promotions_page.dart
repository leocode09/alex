import 'package:flutter/material.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_badge.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_section_header.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final List<Map<String, dynamic>> _promotions = [
    {
      'title': '10% OFF on Bread',
      'description': 'Valid until Dec 31, 2024',
      'type': 'Discount',
      'active': true,
      'code': 'BREAD10',
    },
    {
      'title': 'Buy 2 Get 1 Free - Soda',
      'description': 'Valid for all soda products',
      'type': 'Bundle',
      'active': true,
      'code': 'SODA21',
    },
    {
      'title': 'Happy Hour Special',
      'description': '20% off 5PM - 7PM',
      'type': 'Time-based',
      'active': false,
      'code': 'HAPPY20',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final active = _promotions.where((p) => p['active'] == true).toList();
    final inactive = _promotions.where((p) => p['active'] == false).toList();

    return AppPageScaffold(
      title: 'Promotions',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {},
        ),
        const SizedBox(width: 6),
      ],
      child: ListView(
        children: [
          const AppSectionHeader(title: 'Active Promotions'),
          ...active.map(_buildPromotionTile),
          const SizedBox(height: AppTokens.space4),
          const AppSectionHeader(title: 'Inactive'),
          ...inactive.map(_buildPromotionTile),
        ],
      ),
    );
  }

  Widget _buildPromotionTile(Map<String, dynamic> promo) {
    final isActive = promo['active'] as bool;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space2),
      child: AppPanel(
        emphasized: !isActive,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive ? AppTokens.accentSoft : AppTokens.paperAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? AppTokens.accent : AppTokens.line,
                ),
              ),
              child: Icon(
                Icons.local_offer_outlined,
                color: isActive ? AppTokens.accent : AppTokens.mutedText,
              ),
            ),
            const SizedBox(width: AppTokens.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promo['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    promo['description'] as String,
                    style: const TextStyle(
                        color: AppTokens.mutedText, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppBadge(
                        label: promo['code'] as String,
                        tone: AppBadgeTone.neutral,
                      ),
                      AppBadge(
                        label: promo['type'] as String,
                        tone: AppBadgeTone.accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: isActive,
              onChanged: (value) {
                setState(() {
                  promo['active'] = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
