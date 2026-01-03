import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../themes/app_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Key Metrics
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Today\'s Sales',
                      value: '120,000',
                      unit: 'RWF',
                      trend: '+12%',
                      trendPositive: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Transactions',
                      value: '47',
                      unit: '',
                      trend: '+8%',
                      trendPositive: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Weekly Sales',
                      value: '1.2M',
                      unit: 'RWF',
                      trend: '+15%',
                      trendPositive: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Products',
                      value: '156',
                      unit: '',
                      trend: '+3',
                      trendPositive: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildQuickAction(
                      context,
                      icon: Icons.point_of_sale,
                      label: 'New Sale',
                      onTap: () => context.push('/sales'),
                    ),
                    _buildQuickAction(
                      context,
                      icon: Icons.add_box_outlined,
                      label: 'Add Product',
                      onTap: () => context.push('/products/add'),
                    ),
                    _buildQuickAction(
                      context,
                      icon: Icons.person_add_outlined,
                      label: 'Add Customer',
                      onTap: () => context.push('/customers'),
                    ),
                    _buildQuickAction(
                      context,
                      icon: Icons.receipt_long,
                      label: 'Reports',
                      onTap: () => context.push('/reports'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Alerts Section
              if (true) // Show if there are alerts
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.amberLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.amberSae.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.amberDark, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Low Stock: 4 items need restocking',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.amberDark,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.amberDark),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Top Products
              _buildSectionHeader(context, 'Top Selling Products', () => context.push('/products')),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildTopProductItem(context, 1, 'Coca Cola', '54', '27,000'),
                    _buildTopProductItem(context, 2, 'Bread', '38', '19,000'),
                    _buildTopProductItem(context, 3, 'Sugar', '25', '12,500'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String unit,
    required String trend,
    required bool trendPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: trendPositive ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              trend,
              style: TextStyle(
                color: trendPositive ? Colors.green[700] : Colors.red[700],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Icon(icon, color: Colors.black87, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onViewAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
        ),
        GestureDetector(
          onTap: onViewAll,
          child: Text(
            'View All',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopProductItem(
    BuildContext context,
    int rank,
    String name,
    String sales,
    String revenue,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            '#$rank',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  '$sales sales',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            '$revenue RWF',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
