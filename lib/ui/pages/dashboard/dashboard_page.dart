import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../themes/app_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            Text(
              _getGreeting(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              label: const Text('3'),
              child: const Icon(Icons.notifications_outlined),
            ),
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Key Metrics Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      icon: Icons.attach_money,
                      title: 'Today\'s Sales',
                      value: '120,000',
                      unit: 'RWF',
                      trend: '+12%',
                      trendPositive: true,
                      color: AppTheme.greenPantone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      icon: Icons.shopping_bag_outlined,
                      title: 'Transactions',
                      value: '47',
                      unit: '',
                      trend: '+8%',
                      trendPositive: true,
                      color: AppTheme.amberSae,
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
                      icon: Icons.trending_up,
                      title: 'Weekly Sales',
                      value: '1.2M',
                      unit: 'RWF',
                      trend: '+15%',
                      trendPositive: true,
                      color: const Color(0xFF1E88E5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      icon: Icons.inventory_2_outlined,
                      title: 'Products',
                      value: '156',
                      unit: '',
                      trend: '+3',
                      trendPositive: true,
                      color: const Color(0xFF8E24AA),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Quick Actions
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Alerts Section
              if (true) // Show if there are alerts
                Card(
                  elevation: 2,
                  color: AppTheme.amberLight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.amberSae,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Low Stock Alert',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.amberDark,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '4 items need immediate restocking',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios),
                              onPressed: () => context.push('/inventory'),
                              color: AppTheme.amberSae,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Charts & Analytics Row
              Row(
                children: [
                  Expanded(
                    child: _buildSalesChartCard(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCategoryBreakdownCard(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Top Products
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Top Selling Products',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/products'),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTopProductItem(
                        context,
                        rank: 1,
                        name: 'Coca Cola',
                        sales: 54,
                        revenue: 27000,
                        trend: 12,
                      ),
                      const Divider(height: 24),
                      _buildTopProductItem(
                        context,
                        rank: 2,
                        name: 'Bread',
                        sales: 38,
                        revenue: 19000,
                        trend: 8,
                      ),
                      const Divider(height: 24),
                      _buildTopProductItem(
                        context,
                        rank: 3,
                        name: 'Sugar',
                        sales: 25,
                        revenue: 12500,
                        trend: -3,
                      ),
                      const Divider(height: 24),
                      _buildTopProductItem(
                        context,
                        rank: 4,
                        name: 'Cooking Oil',
                        sales: 22,
                        revenue: 44000,
                        trend: 15,
                      ),
                      const Divider(height: 24),
                      _buildTopProductItem(
                        context,
                        rank: 5,
                        name: 'Milk',
                        sales: 19,
                        revenue: 9500,
                        trend: 5,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Recent Activity & Store Info Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildRecentActivityCard(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStoreInfoCard(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Team Performance
              _buildTeamPerformanceCard(context),
              const SizedBox(height: 20),

              // Customer Insights
              _buildCustomerInsightsCard(context),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required String trend,
    required bool trendPositive,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trendPositive
                        ? AppTheme.greenLight
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendPositive ? Icons.trending_up : Icons.trending_down,
                        size: 12,
                        color: trendPositive ? AppTheme.greenDark : Colors.red,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trend,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: trendPositive ? AppTheme.greenDark : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      unit,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.amberSae.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppTheme.amberSae,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChartCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Sales',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _buildBarChart(context, 'Mon', 0.6)),
                  Expanded(child: _buildBarChart(context, 'Tue', 0.8)),
                  Expanded(child: _buildBarChart(context, 'Wed', 0.5)),
                  Expanded(child: _buildBarChart(context, 'Thu', 0.9)),
                  Expanded(child: _buildBarChart(context, 'Fri', 1.0)),
                  Expanded(child: _buildBarChart(context, 'Sat', 0.7)),
                  Expanded(child: _buildBarChart(context, 'Sun', 0.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, String day, double value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 16,
          height: 80 * value,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.greenPantone,
                AppTheme.greenPantone.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdownCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category Mix',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildCategoryBar(context, 'Beverages', 0.4, AppTheme.greenPantone),
            const SizedBox(height: 8),
            _buildCategoryBar(context, 'Food', 0.35, AppTheme.amberSae),
            const SizedBox(height: 8),
            _buildCategoryBar(context, 'Household', 0.15, const Color(0xFF1E88E5)),
            const SizedBox(height: 8),
            _buildCategoryBar(context, 'Others', 0.1, const Color(0xFF8E24AA)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBar(BuildContext context, String category, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${(percentage * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildTopProductItem(
    BuildContext context, {
    required int rank,
    required String name,
    required int sales,
    required double revenue,
    required int trend,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: rank == 1
                  ? [const Color(0xFFFFD700), const Color(0xFFFFAA00)]
                  : rank == 2
                      ? [const Color(0xFFC0C0C0), const Color(0xFF909090)]
                      : rank == 3
                          ? [const Color(0xFFCD7F32), const Color(0xFF8B4513)]
                          : [Colors.grey.shade300, Colors.grey.shade400],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '$sales sales • ${revenue.toInt()} RWF',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: trend >= 0 ? AppTheme.greenLight : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                trend >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: trend >= 0 ? AppTheme.greenDark : Colors.red,
              ),
              const SizedBox(width: 2),
              Text(
                '${trend.abs()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: trend >= 0 ? AppTheme.greenDark : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildActivityItem(
              context,
              icon: Icons.shopping_cart,
              title: 'New sale recorded',
              time: '2 min ago',
              color: AppTheme.greenPantone,
            ),
            const SizedBox(height: 12),
            _buildActivityItem(
              context,
              icon: Icons.inventory,
              title: 'Stock updated',
              time: '15 min ago',
              color: AppTheme.amberSae,
            ),
            const SizedBox(height: 12),
            _buildActivityItem(
              context,
              icon: Icons.person_add,
              title: 'New customer added',
              time: '1 hour ago',
              color: const Color(0xFF1E88E5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String time,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                time,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoreInfoCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store Status',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildStoreInfoItem(
              context,
              icon: Icons.store,
              label: 'Active Store',
              value: 'Main Branch',
            ),
            const SizedBox(height: 12),
            _buildStoreInfoItem(
              context,
              icon: Icons.schedule,
              label: 'Hours Today',
              value: '8:00 AM - 9:00 PM',
            ),
            const SizedBox(height: 12),
            _buildStoreInfoItem(
              context,
              icon: Icons.people,
              label: 'Staff Online',
              value: '5 employees',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamPerformanceCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Team Performance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => context.push('/employees'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTeamMemberItem(
              context,
              name: 'Alice Johnson',
              role: 'Cashier',
              sales: 15,
              amount: 45000,
              performance: 0.95,
            ),
            const Divider(height: 24),
            _buildTeamMemberItem(
              context,
              name: 'Bob Smith',
              role: 'Sales Associate',
              sales: 12,
              amount: 38000,
              performance: 0.82,
            ),
            const Divider(height: 24),
            _buildTeamMemberItem(
              context,
              name: 'Carol Williams',
              role: 'Cashier',
              sales: 10,
              amount: 32000,
              performance: 0.75,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamMemberItem(
    BuildContext context, {
    required String name,
    required String role,
    required int sales,
    required double amount,
    required double performance,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.amberSae.withOpacity(0.2),
          child: Text(
            name[0],
            style: const TextStyle(
              color: AppTheme.amberSae,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '$role • $sales sales today',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: performance,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    performance >= 0.9
                        ? AppTheme.greenPantone
                        : performance >= 0.7
                            ? AppTheme.amberSae
                            : Colors.orange,
                  ),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${amount.toInt()}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.greenPantone,
                  ),
            ),
            Text(
              'RWF',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerInsightsCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customer Insights',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => context.push('/customers'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInsightMetric(
                    context,
                    icon: Icons.people_outline,
                    label: 'Total Customers',
                    value: '1,234',
                    color: const Color(0xFF1E88E5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInsightMetric(
                    context,
                    icon: Icons.person_add_outlined,
                    label: 'New This Week',
                    value: '23',
                    color: AppTheme.greenPantone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInsightMetric(
                    context,
                    icon: Icons.favorite_outline,
                    label: 'Loyal Customers',
                    value: '187',
                    color: const Color(0xFFE91E63),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInsightMetric(
                    context,
                    icon: Icons.star_outline,
                    label: 'Avg. Rating',
                    value: '4.8',
                    color: AppTheme.amberSae,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightMetric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
