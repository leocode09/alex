import 'package:flutter/material.dart';

import '../../../services/admin/usage_recorder.dart';

/// The metrics the admin can chart over time. Values map to Firestore
/// field names under `usageDaily/{day}`.
enum AdminMetric {
  salesCount(
    label: 'Sales',
    field: UsageRecorder.kSalesCount,
    isCurrency: false,
  ),
  salesAmountCents(
    label: 'Revenue',
    field: UsageRecorder.kSalesAmountCents,
    isCurrency: true,
  ),
  receiptsPrinted(
    label: 'Prints',
    field: UsageRecorder.kReceiptsPrinted,
    isCurrency: false,
  ),
  productsEdited(
    label: 'Edits',
    field: UsageRecorder.kProductsEdited,
    isCurrency: false,
  ),
  appOpens(
    label: 'Opens',
    field: UsageRecorder.kAppOpens,
    isCurrency: false,
  );

  final String label;
  final String field;
  final bool isCurrency;
  const AdminMetric({
    required this.label,
    required this.field,
    required this.isCurrency,
  });
}

/// Horizontal segmented picker for [AdminMetric]. Keeps its own state
/// and notifies via [onChanged].
class AdminMetricPicker extends StatelessWidget {
  final AdminMetric value;
  final ValueChanged<AdminMetric> onChanged;

  const AdminMetricPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final m in AdminMetric.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(m.label),
                selected: m == value,
                onSelected: (_) => onChanged(m),
              ),
            ),
        ],
      ),
    );
  }
}
