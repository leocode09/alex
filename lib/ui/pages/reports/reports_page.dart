import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/sale_provider.dart';
import '../../../providers/product_provider.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'This Week';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports',
            style: TextStyle(fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Sales'),
            Tab(text: 'Inventory'),
            Tab(text: 'Employees'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedPeriod,
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Today', child: Text('Today')),
              const PopupMenuItem(value: 'This Week', child: Text('This Week')),
              const PopupMenuItem(
                  value: 'This Month', child: Text('This Month')),
              const PopupMenuItem(value: 'This Year', child: Text('This Year')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(_selectedPeriod,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSalesTab(),
          _buildInventoryTab(),
          _buildEmployeesTab(),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    final salesAsync = ref.watch(salesProvider);
    final salesCountAsync = ref.watch(totalSalesCountProvider);
    final revenueAsync = ref.watch(totalRevenueProvider);
    final topProductsAsync = ref.watch(topSellingProductsProvider);

    return salesAsync.when(
      data: (allSales) {
        final salesCount = salesCountAsync.value ?? 0;
        final totalRevenue = revenueAsync.value ?? 0.0;
        final avgOrder = salesCount > 0 ? totalRevenue / salesCount : 0.0;

        // Calculate last 7 days revenue for chart
        final now = DateTime.now();
        final last7Days = List.generate(7, (i) {
          final date = now.subtract(Duration(days: 6 - i));
          final dayStart = DateTime(date.year, date.month, date.day);
          final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

          final dayRevenue = allSales.where((sale) {
            return sale.createdAt.isAfter(dayStart) &&
                sale.createdAt.isBefore(dayEnd);
          }).fold<double>(0.0, (sum, sale) => sum + sale.total);

          return FlSpot(
              i.toDouble(), dayRevenue / 1000); // Convert to thousands
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards([
                _SummaryData(
                    'Total Sales', '\$${_formatNumber(totalRevenue)}', ''),
                _SummaryData('Orders', '$salesCount', ''),
                _SummaryData(
                    'Avg. Order', '\$${_formatNumber(avgOrder)}', ''),
              ]),
              const SizedBox(height: 32),
              const Text('Revenue Trend (Last 7 Days)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: last7Days,
                        isCurved: true,
                        color: Theme.of(context).colorScheme.primary,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.05),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text('Top Selling Products',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              topProductsAsync.when(
                data: (topProducts) {
                  if (topProducts.isEmpty) {
                    return const Text('No sales data available');
                  }
                  // Calculate revenue per product
                  final productRevenues = <String, double>{};
                  for (var sale in allSales) {
                    for (var item in sale.items) {
                      productRevenues[item.productName] =
                          (productRevenues[item.productName] ?? 0) +
                              (item.price * item.quantity);
                    }
                  }
                  return Column(
                    children: topProducts.entries.take(4).map((entry) {
                      final revenue = productRevenues[entry.key] ?? 0.0;
                      return _buildListRow(
                          entry.key,
                          '\$${_formatNumber(revenue)}',
                          '${entry.value} units');
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error loading top products'),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildInventoryTab() {
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      data: (products) {
        final totalItems = products.fold<int>(0, (sum, p) => sum + p.stock);
        final lowStockItems = products.where((p) => p.stock < 20).toList();
        final totalValue =
            products.fold<double>(0.0, (sum, p) => sum + (p.price * p.stock));

        // Calculate stock distribution by category
        final categoryStock = <String, int>{};
        for (var product in products) {
          final category = product.category ?? 'Uncategorized';
          categoryStock[category] =
              (categoryStock[category] ?? 0) + product.stock;
        }

        final totalStock =
            categoryStock.values.fold<int>(0, (sum, val) => sum + val);
        final sections = categoryStock.entries.map((entry) {
          final percentage =
              totalStock > 0 ? (entry.value / totalStock * 100) : 0.0;
          final color = categoryStock.keys.toList().indexOf(entry.key) == 0
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[
                  (4 - categoryStock.keys.toList().indexOf(entry.key)) * 200];
          return PieChartSectionData(
            color: color,
            value: percentage,
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: TextStyle(
              color: categoryStock.keys.toList().indexOf(entry.key) == 0
                  ? Colors.white
                  : Colors.black,
              fontSize: 12,
            ),
          );
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards([
                _SummaryData('Total Items', '$totalItems', ''),
                _SummaryData('Low Stock', '${lowStockItems.length}',
                    lowStockItems.isNotEmpty ? 'Alert' : ''),
                _SummaryData('Value', '\$${_formatNumber(totalValue)}', ''),
              ]),
              const SizedBox(height: 32),
              const Text('Stock Distribution by Category',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: sections.isEmpty
                    ? const Center(child: Text('No inventory data'))
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 40,
                          sections: sections,
                        ),
                      ),
              ),
              const SizedBox(height: 32),
              const Text('Low Stock Alerts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (lowStockItems.isEmpty)
                const Text('No low stock items')
              else
                ...lowStockItems.take(5).map((product) {
                  return _buildListRow(
                    product.name,
                    '${product.stock} left',
                    product.stock < 10 ? 'Reorder' : 'Low',
                  );
                }).toList(),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildEmployeesTab() {
    final salesAsync = ref.watch(salesProvider);

    return salesAsync.when(
      data: (allSales) {
        // Group sales by employee
        final employeeStats = <String, Map<String, dynamic>>{};
        for (var sale in allSales) {
          if (!employeeStats.containsKey(sale.employeeId)) {
            employeeStats[sale.employeeId] = {
              'revenue': 0.0,
              'count': 0,
            };
          }
          employeeStats[sale.employeeId]!['revenue'] += sale.total;
          employeeStats[sale.employeeId]!['count']++;
        }

        // Sort by revenue
        final sortedEmployees = employeeStats.entries.toList()
          ..sort((a, b) => (b.value['revenue'] as double)
              .compareTo(a.value['revenue'] as double));

        final topSeller =
            sortedEmployees.isNotEmpty ? sortedEmployees.first : null;
        final activeStaff = employeeStats.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards([
                _SummaryData('Active Staff', '$activeStaff', ''),
                _SummaryData('Total Sales', '${allSales.length}', ''),
                _SummaryData(
                    'Top Seller',
                    topSeller != null ? topSeller.key.split('@').first : 'N/A',
                    topSeller != null
                        ? '\$${_formatNumber(topSeller.value['revenue'] as double)}'
                        : ''),
              ]),
              const SizedBox(height: 32),
              const Text('Performance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (sortedEmployees.isEmpty)
                const Text('No sales data available')
              else
                ...sortedEmployees.take(5).map((entry) {
                  final employeeName = entry.key.split('@').first;
                  final revenue = entry.value['revenue'] as double;
                  final count = entry.value['count'] as int;
                  return _buildListRow(
                    employeeName,
                    '\$${_formatNumber(revenue)}',
                    '$count Sales',
                  );
                }).toList(),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildSummaryCards(List<_SummaryData> data) {
    return Row(
      children: data.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 8),
                Text(item.value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: item.subtitle.contains('-') ||
                              item.subtitle == 'Alert'
                          ? Colors.red
                          : Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildListRow(String title, String value, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }
}

class _SummaryData {
  final String title;
  final String value;
  final String subtitle;

  _SummaryData(this.title, this.value, this.subtitle);
}
