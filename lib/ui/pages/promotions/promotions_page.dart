import 'package:flutter/material.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  // Mock data
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Add promotion
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Active Promotions'),
          ..._promotions.where((p) => p['active'] == true).map(_buildPromotionTile),

          const SizedBox(height: 24),
          _buildSectionHeader('Inactive'),
          ..._promotions.where((p) => p['active'] == false).map(_buildPromotionTile),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildPromotionTile(Map<String, dynamic> promo) {
    final isActive = promo['active'] as bool;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive ? Colors.green[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.local_offer_outlined,
            color: isActive ? Colors.green[700] : Colors.grey[500],
            size: 24,
          ),
        ),
        title: Text(promo['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(promo['description'] as String, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    promo['code'] as String,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    promo['type'] as String,
                    style: TextStyle(color: Colors.blue[700], fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Switch(
          value: isActive,
          activeThumbColor: Colors.black,
          onChanged: (value) {
            setState(() {
              promo['active'] = value;
            });
          },
        ),
      ),
    );
  }
}
