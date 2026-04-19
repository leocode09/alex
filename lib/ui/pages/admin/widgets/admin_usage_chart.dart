import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../services/admin/usage_recorder.dart';
import '../../../design_system/app_theme_extensions.dart';
import '../../../design_system/app_tokens.dart';
import '../../../design_system/widgets/app_panel.dart';
import '../admin_heuristics.dart';
import 'admin_metric_picker.dart';

/// Bar chart + summary of the last N daily usage docs.
///
/// Takes any Firestore stream pointing at a `usageDaily` subcollection
/// (so it works for both shop-scoped and device-scoped views). When
/// [showMetricPicker] is true the card includes an [AdminMetricPicker]
/// and the chart swaps series live.
class AdminUsageChart extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final AdminMetric initialMetric;
  final bool showMetricPicker;

  const AdminUsageChart({
    super.key,
    required this.stream,
    this.initialMetric = AdminMetric.salesCount,
    this.showMetricPicker = false,
  });

  @override
  State<AdminUsageChart> createState() => _AdminUsageChartState();
}

class _AdminUsageChartState extends State<AdminUsageChart> {
  late AdminMetric _metric = widget.initialMetric;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = (snap.data?.docs ?? const []).toList()
          ..sort((a, b) {
            final ad = (a.data()['day'] as String?) ?? a.id;
            final bd = (b.data()['day'] as String?) ?? b.id;
            return ad.compareTo(bd);
          });

        if (docs.isEmpty) {
          return const AppPanel(
            child: Text('No activity recorded yet.'),
          );
        }

        return AppPanel(
          emphasized: true,
          padding: const EdgeInsets.all(AppTokens.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Summary(docs: docs),
              if (widget.showMetricPicker) ...[
                const SizedBox(height: AppTokens.space2),
                AdminMetricPicker(
                  value: _metric,
                  onChanged: (m) => setState(() => _metric = m),
                ),
              ],
              const SizedBox(height: AppTokens.space2),
              SizedBox(
                height: 160,
                child: _Chart(docs: docs, metric: _metric),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const _Summary({required this.docs});

  @override
  Widget build(BuildContext context) {
    int totalSales = 0;
    int totalAmountCents = 0;
    int totalPrints = 0;
    int totalEdits = 0;
    int totalOpens = 0;
    for (final d in docs) {
      final m = d.data();
      totalSales += _asInt(m[UsageRecorder.kSalesCount]);
      totalAmountCents += _asInt(m[UsageRecorder.kSalesAmountCents]);
      totalPrints += _asInt(m[UsageRecorder.kReceiptsPrinted]);
      totalEdits += _asInt(m[UsageRecorder.kProductsEdited]);
      totalOpens += _asInt(m[UsageRecorder.kAppOpens]);
    }
    final amount = AdminHeuristics.fmtMoneyFromCents(totalAmountCents);
    final extras = context.appExtras;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: extras.muted,
        );
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _Tag(icon: Icons.point_of_sale, label: '$totalSales sales'),
        _Tag(icon: Icons.attach_money, label: '$amount revenue'),
        _Tag(icon: Icons.print, label: '$totalPrints prints'),
        _Tag(icon: Icons.edit_note, label: '$totalEdits edits'),
        _Tag(icon: Icons.open_in_new, label: '$totalOpens opens'),
        Text('${docs.length} day(s)', style: style),
      ],
    );
  }

  static int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.appExtras.muted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}

class _Chart extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final AdminMetric metric;

  const _Chart({required this.docs, required this.metric});

  @override
  Widget build(BuildContext context) {
    final values = docs.map((d) {
      final m = d.data();
      final v = m[metric.field];
      if (v is num) {
        return metric.isCurrency ? (v.toDouble() / 100.0) : v.toDouble();
      }
      return 0.0;
    }).toList();
    final maxY = (values.fold<double>(0, (a, b) => a > b ? a : b))
        .clamp(1.0, double.infinity);
    final primary = Theme.of(context).colorScheme.primary;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.15,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= docs.length) return const SizedBox();
                final day = (docs[i].data()['day'] as String?) ?? docs[i].id;
                final short = day.length >= 10 ? day.substring(5) : day;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    short,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, idx, rod, rodIdx) {
              final day = (docs[group.x.toInt()].data()['day'] as String?) ??
                  docs[group.x.toInt()].id;
              final v = rod.toY;
              final formatted = metric.isCurrency
                  ? AdminHeuristics.fmtMoneyFromCents((v * 100).round())
                  : v.toInt().toString();
              return BarTooltipItem(
                '$day\n$formatted',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: primary,
                  width: 10,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
