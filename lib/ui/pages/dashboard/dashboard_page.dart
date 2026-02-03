import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../helpers/pin_protection.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/sale_provider.dart';
import '../../../services/pin_service.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch all providers
    final todaysRevenueAsync = ref.watch(todaysRevenueProvider);
    final yesterdaysRevenueAsync = ref.watch(yesterdaysRevenueProvider);
    final todaysSalesCountAsync = ref.watch(todaysSalesCountProvider);
    final yesterdaysSalesCountAsync = ref.watch(yesterdaysSalesCountProvider);
    final weeklyRevenueAsync = ref.watch(weeklyRevenueProvider);
    final lastWeekRevenueAsync = ref.watch(lastWeekRevenueProvider);
    final totalProductsCountAsync = ref.watch(totalProductsCountProvider);
    final lowStockProductsAsync = ref.watch(lowStockProductsProvider);
    final topSellingProductsAsync = ref.watch(topSellingProductsProvider);
    final allSalesAsync = ref.watch(salesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () async {
              if (await PinProtection.requirePinIfNeeded(
                context,
                isRequired: () => PinService().isPinRequiredForViewNotifications(),
                title: 'Notifications',
                subtitle: 'Enter PIN to view notifications',
              )) {
                context.push('/notifications');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate all providers to refresh data
          ref.invalidate(todaysRevenueProvider);
          ref.invalidate(yesterdaysRevenueProvider);
          ref.invalidate(todaysSalesCountProvider);
          ref.invalidate(yesterdaysSalesCountProvider);
          ref.invalidate(weeklyRevenueProvider);
          ref.invalidate(lastWeekRevenueProvider);
          ref.invalidate(totalProductsCountProvider);
          ref.invalidate(lowStockProductsProvider);
          ref.invalidate(topSellingProductsProvider);
          ref.invalidate(salesProvider);
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
                    child: todaysRevenueAsync.when(
                      data: (todaysRevenue) {
                        final yesterdaysRevenue = yesterdaysRevenueAsync.value ?? 0.0;
                        final trend = yesterdaysRevenue > 0
                            ? ((todaysRevenue - yesterdaysRevenue) / yesterdaysRevenue * 100)
                            : 0.0;
                        return _buildMetricCard(
                          context,
                          title: 'Today\'s Sales',
                          value: '\$${_formatNumber(todaysRevenue)}',
                          unit: '',
                          trend: '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(0)}%',
                          trendPositive: trend >= 0,
                        );
                      },
                      loading: () => _buildMetricCard(
                        context,
                        title: 'Today\'s Sales',
                        value: '...',
                        unit: '',
                        trend: '--',
                        trendPositive: true,
                      ),
                      error: (_, __) => _buildMetricCard(
                        context,
                        title: 'Today\'s Sales',
                        value: '\$0',
                        unit: '',
                        trend: '--',
                        trendPositive: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: todaysSalesCountAsync.when(
                      data: (todaysSalesCount) {
                        final yesterdaysSalesCount = yesterdaysSalesCountAsync.value ?? 0;
                        final diff = todaysSalesCount - yesterdaysSalesCount;
                        final trend = yesterdaysSalesCount > 0
                            ? ((diff / yesterdaysSalesCount) * 100)
                            : 0.0;
                        return _buildMetricCard(
                          context,
                          title: 'Transactions',
                          value: '$todaysSalesCount',
                          unit: '',
                          trend: '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(0)}%',
                          trendPositive: trend >= 0,
                        );
                      },
                      loading: () => _buildMetricCard(
                        context,
                        title: 'Transactions',
                        value: '...',
                        unit: '',
                        trend: '--',
                        trendPositive: true,
                      ),
                      error: (_, __) => _buildMetricCard(
                        context,
                        title: 'Transactions',
                        value: '0',
                        unit: '',
                        trend: '--',
                        trendPositive: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: weeklyRevenueAsync.when(
                      data: (weeklyRevenue) {
                        final lastWeekRevenue = lastWeekRevenueAsync.value ?? 0.0;
                        final trend = lastWeekRevenue > 0
                            ? ((weeklyRevenue - lastWeekRevenue) / lastWeekRevenue * 100)
                            : 0.0;
                        return _buildMetricCard(
                          context,
                          title: 'Weekly Sales',
                          value: '\$${_formatNumber(weeklyRevenue)}',
                          unit: '',
                          trend: '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(0)}%',
                          trendPositive: trend >= 0,
                        );
                      },
                      loading: () => _buildMetricCard(
                        context,
                        title: 'Weekly Sales',
                        value: '...',
                        unit: '',
                        trend: '--',
                        trendPositive: true,
                      ),
                      error: (_, __) => _buildMetricCard(
                        context,
                        title: 'Weekly Sales',
                        value: '\$0',
                        unit: '',
                        trend: '--',
                        trendPositive: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: totalProductsCountAsync.when(
                      data: (totalProducts) {
                        return _buildMetricCard(
                          context,
                          title: 'Products',
                          value: '$totalProducts',
                          unit: '',
                          trend: '',
                          trendPositive: true,
                        );
                      },
                      loading: () => _buildMetricCard(
                        context,
                        title: 'Products',
                        value: '...',
                        unit: '',
                        trend: '',
                        trendPositive: true,
                      ),
                      error: (_, __) => _buildMetricCard(
                        context,
                        title: 'Products',
                        value: '0',
                        unit: '',
                        trend: '',
                        trendPositive: true,
                      ),
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
                      onTap: () async {
                        if (await PinProtection.requirePinIfNeeded(
                          context,
                          isRequired: () => PinService().isPinRequiredForCreateSale(),
                          title: 'New Sale',
                          subtitle: 'Enter PIN to create a sale',
                        )) {
                          context.push('/sales');
                        }
                      },
                    ),
                    _buildQuickAction(
                      context,
                      icon: Icons.add_box_outlined,
                      label: 'Add Product',
                      onTap: () async {
                        if (await PinProtection.requirePinIfNeeded(
                          context,
                          isRequired: () => PinService().isPinRequiredForAddProduct(),
                          title: 'Add Product',
                          subtitle: 'Enter PIN to add a product',
                        )) {
                          context.push('/products/add');
                        }
                      },
                    ),
                    _buildQuickAction(
                      context,
                      icon: Icons.person_add_outlined,
                      label: 'Add Customer',
                      onTap: () async {
                        if (await PinProtection.requirePinIfNeeded(
                          context,
                          isRequired: () => PinService().isPinRequiredForAddCustomer(),
                          title: 'Add Customer',
                          subtitle: 'Enter PIN to add a customer',
                        )) {
                          context.push('/customers');
                        }
                      },
                    ),
                    _buildQuickAction(
                      context,
                      icon: Icons.receipt_long,
                      label: 'Reports',
                      onTap: () async {
                        if (await PinProtection.requirePinIfNeeded(
                          context,
                          isRequired: () => PinService().isPinRequiredForReports(),
                          title: 'Reports Access',
                          subtitle: 'Enter PIN to view reports',
                        )) {
                          context.push('/reports');
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Alerts Section
              lowStockProductsAsync.when(
                data: (lowStockProducts) {
                  if (lowStockProducts.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/inventory'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Low Stock: ${lowStockProducts.length} items need restocking',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.orange[800]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Top Products
              _buildSectionHeader(context, 'Top Selling Products', () => context.push('/products')),
              const SizedBox(height: 12),
              topSellingProductsAsync.when(
                data: (topProducts) {
                  if (topProducts.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('No sales data available'),
                      ),
                    );
                  }

                  // Calculate revenue for each product
                  final allSales = allSalesAsync.value ?? [];
                  final productRevenues = <String, double>{};
                  for (var sale in allSales) {
                    for (var item in sale.items) {
                      productRevenues[item.productName] =
                          (productRevenues[item.productName] ?? 0) +
                              (item.price * item.quantity);
                    }
                  }

                  final topProductsList = topProducts.entries.take(3).toList();
                  
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: topProductsList.asMap().entries.map((entry) {
                        final index = entry.key;
                        final product = entry.value;
                        final revenue = productRevenues[product.key] ?? 0.0;
                        return Column(
                          children: [
                            _buildTopProductItem(
                              context,
                              index + 1,
                              product.key,
                              '${product.value}',
                              _formatNumber(revenue),
                            ),
                            if (index < topProductsList.length - 1)
                              Divider(height: 1, color: Colors.grey[200]),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
                loading: () => Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('Error loading top products'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toStringAsFixed(2);
    }
  }

  static Widget _buildMetricCard(
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
                      color: Theme.of(context).colorScheme.onSurface,
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
          if (trend.isNotEmpty) ...[
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
        ],
      ),
    );
  }

  static Widget _buildQuickAction(
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
              child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
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

  static Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onViewAll) {
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
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  static Widget _buildTopProductItem(
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
            '\$$revenue',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
