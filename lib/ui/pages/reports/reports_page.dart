import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with SingleTickerProviderStateMixin {
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
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w600)),
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
              const PopupMenuItem(value: 'This Month', child: Text('This Month')),
              const PopupMenuItem(value: 'This Year', child: Text('This Year')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(_selectedPeriod, style: const TextStyle(fontWeight: FontWeight.w500)),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards([
            _SummaryData('Total Sales', 'RWF 2.5M', '+12%'),
            _SummaryData('Orders', '145', '+5%'),
            _SummaryData('Avg. Order', 'RWF 17K', '-2%'),
          ]),
          const SizedBox(height: 32),
          const Text('Revenue Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    spots: const [
                      FlSpot(0, 3),
                      FlSpot(1, 1),
                      FlSpot(2, 4),
                      FlSpot(3, 2),
                      FlSpot(4, 5),
                      FlSpot(5, 3),
                      FlSpot(6, 4),
                    ],
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Top Selling Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildListRow('Wireless Headphones', 'RWF 450K', '15 units'),
          _buildListRow('Smart Watch', 'RWF 320K', '8 units'),
          _buildListRow('Laptop Stand', 'RWF 120K', '24 units'),
          _buildListRow('USB-C Cable', 'RWF 85K', '45 units'),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards([
            _SummaryData('Total Items', '1,240', ''),
            _SummaryData('Low Stock', '12', 'Alert'),
            _SummaryData('Value', 'RWF 45M', ''),
          ]),
          const SizedBox(height: 32),
          const Text('Stock Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(color: Theme.of(context).colorScheme.primary, value: 40, title: '40%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 12)),
                  PieChartSectionData(color: Colors.grey[400], value: 30, title: '30%', radius: 50, titleStyle: const TextStyle(color: Colors.black, fontSize: 12)),
                  PieChartSectionData(color: Colors.grey[200], value: 15, title: '15%', radius: 50, titleStyle: const TextStyle(color: Colors.black, fontSize: 12)),
                  PieChartSectionData(color: Colors.grey[100], value: 15, title: '15%', radius: 50, titleStyle: const TextStyle(color: Colors.black, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Low Stock Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildListRow('Printer Paper A4', '5 left', 'Reorder'),
          _buildListRow('Black Ink Cartridge', '2 left', 'Reorder'),
          _buildListRow('Staples', '10 left', 'Low'),
        ],
      ),
    );
  }

  Widget _buildEmployeesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards([
            _SummaryData('Active Staff', '8', ''),
            _SummaryData('Total Hours', '320', 'This Week'),
            _SummaryData('Top Seller', 'Alice', 'RWF 1.2M'),
          ]),
          const SizedBox(height: 32),
          const Text('Performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildListRow('Alice Johnson', 'RWF 1.2M', '45 Sales'),
          _buildListRow('Bob Smith', 'RWF 950K', '38 Sales'),
          _buildListRow('Charlie Brown', 'RWF 820K', '30 Sales'),
        ],
      ),
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
                Text(item.title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 8),
                Text(item.value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: item.subtitle.contains('-') || item.subtitle == 'Alert' ? Colors.red : Colors.green,
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
              Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SummaryData {
  final String title;
  final String value;
  final String subtitle;

  _SummaryData(this.title, this.value, this.subtitle);
}
