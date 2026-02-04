import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/product.dart';
import '../../../models/sale.dart';
import '../../../providers/sale_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../helpers/pin_protection.dart';
import '../../../services/pin_service.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'This Week';
  final NumberFormat _currencyFormat =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final NumberFormat _countFormat = NumberFormat.decimalPattern();

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
          onTap: _handleTabTap,
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
        physics: const NeverScrollableScrollPhysics(),
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
    final productsAsync = ref.watch(productsProvider);

    return salesAsync.when(
      data: (allSales) {
        final products = productsAsync.maybeWhen(
          data: (items) => items,
          orElse: () => const <Product>[],
        );
        final range = _getPeriodRange(_selectedPeriod);
        final filteredSales = _filterSalesByRange(allSales, range);
        final metrics = _calculateSalesMetrics(filteredSales, products);
        final chartSpots = _buildRevenueSeries(filteredSales, range);
        final productStats = _buildProductStats(filteredSales);
        final topByRevenue = productStats.entries.toList()
          ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
        final topByUnits = productStats.entries.toList()
          ..sort((a, b) => b.value.units.compareTo(a.value.units));
        final paymentEntries = metrics.paymentBreakdown.entries.toList()
          ..sort((a, b) => b.value.total.compareTo(a.value.total));

        final hasSales = filteredSales.isNotEmpty;
        final hasCostData = metrics.costedItems > 0;
        final hasMissingCost = metrics.missingCostItems > 0;
        final isCostLoading = productsAsync.isLoading;
        final hasCostError = productsAsync.hasError;

        String costSubtitle = '';
        Color? costSubtitleColor;
        if (hasCostError) {
          costSubtitle = 'Cost data unavailable';
          costSubtitleColor = Colors.red;
        } else if (isCostLoading && !hasCostData) {
          costSubtitle = 'Cost data loading';
          costSubtitleColor = Colors.orange[700];
        } else if (hasMissingCost) {
          costSubtitle =
              'Missing cost: ${_formatCount(metrics.missingCostItems)} items';
          costSubtitleColor = Colors.orange[700];
        }

        String profitSubtitle = '';
        Color? profitSubtitleColor;
        if (hasCostError) {
          profitSubtitle = 'Cost data unavailable';
          profitSubtitleColor = Colors.red;
        } else if (isCostLoading && !hasCostData) {
          profitSubtitle = 'Cost data loading';
          profitSubtitleColor = Colors.orange[700];
        } else if (hasMissingCost) {
          profitSubtitle = 'Partial cost';
          profitSubtitleColor = Colors.orange[700];
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards([
                _SummaryData(
                    'Recorded Sales',
                    _formatCurrency(metrics.recordedSales),
                    ''),
                _SummaryData('Orders', _formatCount(metrics.orders), ''),
                _SummaryData(
                    'Items Sold', _formatCount(metrics.itemsSold), ''),
              ]),
              const SizedBox(height: 12),
              _buildSummaryCards([
                _SummaryData(
                  'Net Sales',
                  _formatCurrency(metrics.netSales),
                  metrics.adjustments.abs() > 0.01
                      ? 'Adj: ${_formatSignedCurrency(metrics.adjustments)}'
                      : '',
                ),
                _SummaryData(
                    'Discounts', _formatCurrency(metrics.discounts), ''),
                _SummaryData(
                  'Avg. Order',
                  metrics.orders > 0 ? _formatCurrency(metrics.avgOrder) : 'N/A',
                  '',
                ),
              ]),
              const SizedBox(height: 12),
              _buildSummaryCards([
                _SummaryData(
                  'COGS',
                  hasCostData ? _formatCurrency(metrics.cogs) : 'N/A',
                  costSubtitle,
                  subtitleColor: costSubtitleColor,
                ),
                _SummaryData(
                  'Gross Profit',
                  hasCostData ? _formatCurrency(metrics.grossProfit) : 'N/A',
                  profitSubtitle,
                  subtitleColor: profitSubtitleColor,
                ),
                _SummaryData(
                  'Margin',
                  hasCostData && metrics.netSales > 0
                      ? _formatPercent(metrics.grossMargin)
                      : 'N/A',
                  '',
                ),
              ]),
              const SizedBox(height: 28),
              if (!hasSales)
                const Text('No sales data for this period')
              else ...[
                Text(
                  'Revenue Trend (${_periodLabel(_selectedPeriod)})',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
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
                          spots: chartSpots,
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
                const SizedBox(height: 28),
                const Text('Payment Methods',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (paymentEntries.isEmpty)
                  const Text('No payment data available')
                else
                  ...paymentEntries.map((entry) {
                    final share = metrics.recordedSales > 0
                        ? entry.value.total / metrics.recordedSales
                        : 0.0;
                    return _buildListRow(
                      entry.key,
                      _formatCurrency(entry.value.total),
                      '${_formatCount(entry.value.count)} sales | ${_formatPercent(share)}',
                    );
                  }).toList(),
                const SizedBox(height: 28),
                const Text('Top Products by Revenue',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (topByRevenue.isEmpty)
                  const Text('No sales data available')
                else
                  ...topByRevenue.take(4).map((entry) {
                    return _buildListRow(
                      entry.key,
                      _formatCurrency(entry.value.revenue),
                      '${_formatCount(entry.value.units)} units',
                    );
                  }).toList(),
                const SizedBox(height: 20),
                const Text('Top Products by Units',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (topByUnits.isEmpty)
                  const Text('No sales data available')
                else
                  ...topByUnits.take(4).map((entry) {
                    return _buildListRow(
                      entry.key,
                      _formatCount(entry.value.units),
                      'Revenue: ${_formatCurrency(entry.value.revenue)}',
                    );
                  }).toList(),
              ],
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
        final totalProducts = products.length;
        final totalUnits = products.fold<int>(0, (sum, p) => sum + p.stock);
        final lowStockItems =
            products.where((p) => p.stock > 0 && p.stock < 20).toList();
        final outOfStockItems = products.where((p) => p.stock == 0).toList();
        final retailValue =
            products.fold<double>(0.0, (sum, p) => sum + (p.price * p.stock));
        double costValue = 0.0;
        int costedUnits = 0;
        int missingCostUnits = 0;
        for (var product in products) {
          if (product.costPrice != null) {
            costValue += product.costPrice! * product.stock;
            costedUnits += product.stock;
          } else if (product.stock > 0) {
            missingCostUnits += product.stock;
          }
        }
        final hasCostData = costedUnits > 0;

        // Calculate stock distribution by category
        final categoryStock = <String, int>{};
        for (var product in products) {
          final category = product.category ?? 'Uncategorized';
          categoryStock[category] =
              (categoryStock[category] ?? 0) + product.stock;
        }

        final totalStock =
            categoryStock.values.fold<int>(0, (sum, val) => sum + val);
        final categoryEntries = categoryStock.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final palette = [
          Theme.of(context).colorScheme.primary,
          Colors.blue.shade300,
          Colors.orange.shade300,
          Colors.green.shade300,
          Colors.purple.shade300,
          Colors.teal.shade300,
          Colors.grey.shade400,
        ];
        final sections = <PieChartSectionData>[];
        for (var i = 0; i < categoryEntries.length; i++) {
          final entry = categoryEntries[i];
          final percentage =
              totalStock > 0 ? (entry.value / totalStock * 100) : 0.0;
          final color = palette[i % palette.length];
          sections.add(
            PieChartSectionData(
              color: color,
              value: percentage,
              title: '${percentage.toStringAsFixed(0)}%',
              radius: 50,
              titleStyle: TextStyle(
                color: i == 0 ? Colors.white : Colors.black,
                fontSize: 12,
              ),
            ),
          );
        }

        final topValueProducts = [...products]
          ..sort((a, b) =>
              (b.price * b.stock).compareTo(a.price * a.stock));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards([
                _SummaryData('Products', _formatCount(totalProducts), ''),
                _SummaryData('Total Units', _formatCount(totalUnits), ''),
                _SummaryData('Low Stock', _formatCount(lowStockItems.length),
                    lowStockItems.isNotEmpty ? 'Alert' : ''),
              ]),
              const SizedBox(height: 12),
              _buildSummaryCards([
                _SummaryData('Out of Stock', _formatCount(outOfStockItems.length),
                    outOfStockItems.isNotEmpty ? 'Alert' : ''),
                _SummaryData(
                    'Retail Value', _formatCurrency(retailValue), ''),
                _SummaryData(
                  'Cost Value',
                  hasCostData ? _formatCurrency(costValue) : 'N/A',
                  missingCostUnits > 0
                      ? 'Missing cost: ${_formatCount(missingCostUnits)} units'
                      : '',
                  subtitleColor:
                      missingCostUnits > 0 ? Colors.orange[700] : null,
                ),
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
              const Text('Top Stock Value',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (topValueProducts.isEmpty)
                const Text('No inventory data')
              else
                ...topValueProducts.take(5).map((product) {
                  final value = product.price * product.stock;
                  return _buildListRow(
                    product.name,
                    _formatCurrency(value),
                    '${_formatCount(product.stock)} units',
                  );
                }).toList(),
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
                    '${_formatCount(product.stock)} left',
                    product.stock < 10 ? 'Reorder' : 'Low',
                  );
                }).toList(),
              if (outOfStockItems.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text('Out of Stock',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...outOfStockItems.take(5).map((product) {
                  return _buildListRow(
                    product.name,
                    '0 units',
                    'Restock',
                  );
                }).toList(),
              ],
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
        final range = _getPeriodRange(_selectedPeriod);
        final filteredSales = _filterSalesByRange(allSales, range);
        final employeeStats = <String, _EmployeePerformance>{};
        double totalRevenue = 0.0;
        for (var sale in filteredSales) {
          final saleTotal = _saleCalculatedTotal(sale);
          totalRevenue += saleTotal;
          final stats = employeeStats.putIfAbsent(
              sale.employeeId, () => _EmployeePerformance());
          stats.revenue += saleTotal;
          stats.orders += 1;
        }

        final sortedByRevenue = employeeStats.entries.toList()
          ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
        final sortedByOrders = employeeStats.entries.toList()
          ..sort((a, b) => b.value.orders.compareTo(a.value.orders));

        final topSeller =
            sortedByRevenue.isNotEmpty ? sortedByRevenue.first : null;
        final mostOrders =
            sortedByOrders.isNotEmpty ? sortedByOrders.first : null;
        final activeStaff = employeeStats.length;
        final totalSales = filteredSales.length;
        final avgOrder =
            totalSales > 0 ? totalRevenue / totalSales : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards([
                _SummaryData('Active Staff', _formatCount(activeStaff), ''),
                _SummaryData('Total Sales', _formatCount(totalSales), ''),
                _SummaryData(
                    'Revenue', _formatCurrency(totalRevenue), ''),
              ]),
              const SizedBox(height: 12),
              _buildSummaryCards([
                _SummaryData('Avg. Order',
                    totalSales > 0 ? _formatCurrency(avgOrder) : 'N/A', ''),
                _SummaryData(
                    'Top Seller',
                    topSeller != null ? topSeller.key.split('@').first : 'N/A',
                    topSeller != null
                        ? _formatCurrency(topSeller.value.revenue)
                        : ''),
                _SummaryData(
                    'Most Orders',
                    mostOrders != null ? mostOrders.key.split('@').first : 'N/A',
                    mostOrders != null
                        ? '${_formatCount(mostOrders.value.orders)} orders'
                        : ''),
              ]),
              const SizedBox(height: 32),
              const Text('Performance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (sortedByRevenue.isEmpty)
                const Text('No sales data available')
              else
                ...sortedByRevenue.take(5).map((entry) {
                  final employeeName = entry.key.split('@').first;
                  final revenue = entry.value.revenue;
                  final count = entry.value.orders;
                  final share = totalRevenue > 0 ? revenue / totalRevenue : 0.0;
                  return _buildListRow(
                    employeeName,
                    _formatCurrency(revenue),
                    '${_formatCount(count)} orders | ${_formatPercent(share)}',
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

  Future<void> _handleTabTap(int index) async {
    final previousIndex = _tabController.index;
    if (index == previousIndex) {
      return;
    }

    bool allowed = true;
    if (index == 0) {
      allowed = await PinProtection.requirePinIfNeeded(
        context,
        isRequired: () => PinService().isPinRequiredForViewFinancialReports(),
        title: 'Financial Reports',
        subtitle: 'Enter PIN to view financial reports',
      );
    } else if (index == 1) {
      allowed = await PinProtection.requirePinIfNeeded(
        context,
        isRequired: () => PinService().isPinRequiredForViewInventoryReports(),
        title: 'Inventory Reports',
        subtitle: 'Enter PIN to view inventory reports',
      );
    }

    if (!allowed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _tabController.index = previousIndex;
        }
      });
    }
  }

  DateTimeRange _getPeriodRange(String period) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (period) {
      case 'Today':
        return DateTimeRange(start: startOfToday, end: endOfToday);
      case 'This Week':
        final start = startOfToday.subtract(const Duration(days: 6));
        return DateTimeRange(start: start, end: endOfToday);
      case 'This Month':
        final start = DateTime(now.year, now.month, 1);
        final nextMonth = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        final end = nextMonth.subtract(const Duration(milliseconds: 1));
        return DateTimeRange(start: start, end: end);
      case 'This Year':
      default:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year + 1, 1, 1)
            .subtract(const Duration(milliseconds: 1));
        return DateTimeRange(start: start, end: end);
    }
  }

  List<Sale> _filterSalesByRange(List<Sale> sales, DateTimeRange range) {
    return sales.where((sale) {
      return !sale.createdAt.isBefore(range.start) &&
          !sale.createdAt.isAfter(range.end);
    }).toList();
  }

  List<FlSpot> _buildRevenueSeries(
      List<Sale> sales, DateTimeRange range) {
    if (range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day) {
      return List.generate(24, (i) {
        final hourStart = DateTime(
            range.start.year, range.start.month, range.start.day, i);
        final hourEnd = hourStart.add(const Duration(hours: 1));
        final revenue = sales.where((sale) {
          return !sale.createdAt.isBefore(hourStart) &&
              sale.createdAt.isBefore(hourEnd);
        }).fold<double>(
            0.0, (sum, sale) => sum + _saleCalculatedTotal(sale));
        return FlSpot(i.toDouble(), revenue);
      });
    }

    final dayCount = range.end.difference(range.start).inDays + 1;
    if (dayCount <= 31) {
      return List.generate(dayCount, (i) {
        final day = range.start.add(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
        final revenue = sales.where((sale) {
          return !sale.createdAt.isBefore(dayStart) &&
              !sale.createdAt.isAfter(dayEnd);
        }).fold<double>(
            0.0, (sum, sale) => sum + _saleCalculatedTotal(sale));
        return FlSpot(i.toDouble(), revenue);
      });
    }

    return List.generate(12, (i) {
      final monthStart = DateTime(range.start.year, i + 1, 1);
      final monthEnd = i == 11
          ? DateTime(range.start.year + 1, 1, 1)
              .subtract(const Duration(milliseconds: 1))
          : DateTime(range.start.year, i + 2, 1)
              .subtract(const Duration(milliseconds: 1));
      final revenue = sales.where((sale) {
        return !sale.createdAt.isBefore(monthStart) &&
            !sale.createdAt.isAfter(monthEnd);
      }).fold<double>(
          0.0, (sum, sale) => sum + _saleCalculatedTotal(sale));
      return FlSpot(i.toDouble(), revenue);
    });
  }

  String _periodLabel(String period) {
    switch (period) {
      case 'Today':
        return 'Today';
      case 'This Week':
        return 'Last 7 Days';
      case 'This Month':
        return 'This Month';
      case 'This Year':
      default:
        return 'This Year';
    }
  }

  double _saleCalculatedTotal(Sale sale) {
    return sale.items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
  }

  _SalesMetrics _calculateSalesMetrics(
      List<Sale> sales, List<Product> products) {
    final productById = {for (final product in products) product.id: product};
    double recordedSales = 0.0;
    double discounts = 0.0;
    double netSales = 0.0;
    double cogs = 0.0;
    int itemsSold = 0;
    int missingCostItems = 0;
    int costedItems = 0;
    final paymentBreakdown = <String, _PaymentMetrics>{};

    for (final sale in sales) {
      recordedSales += sale.total;
      final saleNet = _saleCalculatedTotal(sale);
      netSales += saleNet;

      final method =
          sale.paymentMethod.isNotEmpty ? sale.paymentMethod : 'Unknown';
      final existing = paymentBreakdown[method];
      if (existing == null) {
        paymentBreakdown[method] = _PaymentMetrics(total: sale.total, count: 1);
      } else {
        paymentBreakdown[method] = _PaymentMetrics(
          total: existing.total + sale.total,
          count: existing.count + 1,
        );
      }

      for (final item in sale.items) {
        final itemDiscount = (item.discount ?? 0) * item.quantity;
        discounts += itemDiscount;
        itemsSold += item.quantity;

        final product = productById[item.productId];
        final costPrice = product?.costPrice;
        if (costPrice != null) {
          cogs += costPrice * item.quantity;
          costedItems += item.quantity;
        } else {
          missingCostItems += item.quantity;
        }
      }
    }

    final orders = sales.length;
    final avgOrder = orders > 0 ? netSales / orders : 0.0;
    final adjustments = recordedSales - netSales;
    final grossProfit = netSales - cogs;
    final grossMargin = netSales > 0 ? grossProfit / netSales : 0.0;

    return _SalesMetrics(
      recordedSales: recordedSales,
      discounts: discounts,
      netSales: netSales,
      adjustments: adjustments,
      orders: orders,
      itemsSold: itemsSold,
      avgOrder: avgOrder,
      cogs: cogs,
      grossProfit: grossProfit,
      grossMargin: grossMargin,
      missingCostItems: missingCostItems,
      costedItems: costedItems,
      paymentBreakdown: paymentBreakdown,
    );
  }

  Map<String, _ProductPerformance> _buildProductStats(List<Sale> sales) {
    final stats = <String, _ProductPerformance>{};
    for (final sale in sales) {
      for (final item in sale.items) {
        final entry =
            stats.putIfAbsent(item.productName, () => _ProductPerformance());
        entry.units += item.quantity;
        entry.revenue += item.subtotal;
      }
    }
    return stats;
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
                        fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: item.subtitleColor ??
                          (item.subtitle.contains('-') ||
                                  item.subtitle == 'Alert'
                              ? Colors.red
                              : Colors.green),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    return _currencyFormat.format(value);
  }

  String _formatSignedCurrency(double value) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign${_formatCurrency(value.abs())}';
  }

  String _formatCount(num value) {
    return _countFormat.format(value);
  }

  String _formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}

class _SummaryData {
  final String title;
  final String value;
  final String subtitle;
  final Color? subtitleColor;

  _SummaryData(this.title, this.value, this.subtitle, {this.subtitleColor});
}

class _SalesMetrics {
  final double recordedSales;
  final double discounts;
  final double netSales;
  final double adjustments;
  final int orders;
  final int itemsSold;
  final double avgOrder;
  final double cogs;
  final double grossProfit;
  final double grossMargin;
  final int missingCostItems;
  final int costedItems;
  final Map<String, _PaymentMetrics> paymentBreakdown;

  _SalesMetrics({
    required this.recordedSales,
    required this.discounts,
    required this.netSales,
    required this.adjustments,
    required this.orders,
    required this.itemsSold,
    required this.avgOrder,
    required this.cogs,
    required this.grossProfit,
    required this.grossMargin,
    required this.missingCostItems,
    required this.costedItems,
    required this.paymentBreakdown,
  });
}

class _PaymentMetrics {
  final double total;
  final int count;

  _PaymentMetrics({required this.total, required this.count});
}

class _ProductPerformance {
  int units = 0;
  double revenue = 0.0;
}

class _EmployeePerformance {
  int orders = 0;
  double revenue = 0.0;
}
