import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/license_gate.dart';
import '../../../helpers/pin_protection.dart';
import '../../../models/customer.dart';
import '../../../models/license_policy.dart';
import '../../../models/sale.dart';
import '../../../providers/printer_provider.dart';
import '../../../repositories/sale_repository.dart';
import '../../../providers/receipt_provider.dart';
import '../../../providers/sale_provider.dart';
import '../../../services/data_sync_triggers.dart';
import '../../../services/pin_service.dart';
import '../../../services/receipt_print_service.dart';
import '../../../services/sync_event_bus.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_empty_state.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_search_field.dart';
import '../../design_system/widgets/app_stat_tile.dart';
import 'customer_list_page.dart';

enum _CustomerFilter { all, hasDue, hasCredit, active30 }

enum _CustomerSort { name, amountDue, credit, totalSpent, lastSale }

class CustomerManagementPage extends ConsumerStatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  ConsumerState<CustomerManagementPage> createState() =>
      _CustomerManagementPageState();
}

class _CustomerManagementPageState
    extends ConsumerState<CustomerManagementPage> {
  final _searchController = TextEditingController();
  String _query = '';
  _CustomerFilter _filter = _CustomerFilter.all;
  _CustomerSort _sort = _CustomerSort.amountDue;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(customerSummariesProvider);
    final totalDueAsync = ref.watch(totalAmountDueProvider);
    final totalCreditAsync = ref.watch(totalCreditOutstandingProvider);
    final totalBonusAsync = ref.watch(totalBonusEarnedProvider);
    final extras = context.appExtras;

    return AppPageScaffold(
      title: 'Customer Management',
      actions: [
        PopupMenuButton<_CustomerSort>(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort',
          onSelected: (value) => setState(() => _sort = value),
          itemBuilder: (context) => [
            for (final sort in _CustomerSort.values)
              CheckedPopupMenuItem(
                value: sort,
                checked: _sort == sort,
                child: Text(_sortLabel(sort)),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add customer',
          onPressed: () async {
            if (await PinProtection.requirePinIfNeeded(
              context,
              isRequired: () => PinService().isPinRequiredForAddCustomer(),
              title: 'Add Customer',
              subtitle: 'Enter PIN to add a customer',
            )) {
              if (!context.mounted) return;
              await showCustomerEditorSheet(context, ref: ref);
            }
          },
        ),
      ],
      child: summariesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (summaries) {
          final filtered = _filterAndSort(summaries);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _SummaryGrid(
                  customerCount: summaries.length,
                  amountDue: totalDueAsync.asData?.value ?? 0,
                  storeCredit: totalCreditAsync.asData?.value ?? 0,
                  bonuses: totalBonusAsync.asData?.value ?? 0,
                ),
              ),
              const SliverToBoxAdapter(
                  child: SizedBox(height: AppTokens.space3)),
              SliverToBoxAdapter(
                child: AppSearchField(
                  controller: _searchController,
                  hintText: 'Search customers...',
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              const SliverToBoxAdapter(
                  child: SizedBox(height: AppTokens.space2)),
              SliverToBoxAdapter(child: _buildFilterChips(context)),
              const SliverToBoxAdapter(
                  child: SizedBox(height: AppTokens.space3)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.space2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Customers',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                      ),
                      Text(
                        '${filtered.length} of ${summaries.length}',
                        style: TextStyle(color: extras.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppTokens.space4),
                    child: AppEmptyState(
                      icon: Icons.people_alt_outlined,
                      title: summaries.isEmpty
                          ? 'No customers yet'
                          : 'No matches',
                      subtitle: summaries.isEmpty
                          ? 'Add a customer to start tracking amount due, store credit and bonuses.'
                          : 'Try a different search or filter.',
                    ),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTokens.space2),
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    return _CustomerRow(
                      summary: s,
                      onTap: () => _openProfile(context, s.customer),
                      onRecordPayment: s.amountDue > 0.000001
                          ? () => _showRepaymentDialog(context, s)
                          : null,
                    );
                  },
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppTokens.space4),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(_CustomerFilter.all, 'All'),
          const SizedBox(width: 6),
          _filterChip(_CustomerFilter.hasDue, 'Has amount due'),
          const SizedBox(width: 6),
          _filterChip(_CustomerFilter.hasCredit, 'Has credit'),
          const SizedBox(width: 6),
          _filterChip(_CustomerFilter.active30, 'Active 30d'),
        ],
      ),
    );
  }

  Widget _filterChip(_CustomerFilter value, String label) {
    return FilterChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  String _sortLabel(_CustomerSort sort) {
    switch (sort) {
      case _CustomerSort.name:
        return 'Sort: Name';
      case _CustomerSort.amountDue:
        return 'Sort: Amount due';
      case _CustomerSort.credit:
        return 'Sort: Store credit';
      case _CustomerSort.totalSpent:
        return 'Sort: Total spent';
      case _CustomerSort.lastSale:
        return 'Sort: Last sale';
    }
  }

  List<CustomerSummary> _filterAndSort(List<CustomerSummary> input) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final filtered = input.where((s) {
      if (_query.isNotEmpty) {
        final c = s.customer;
        final matches = c.name.toLowerCase().contains(_query) ||
            (c.phone?.toLowerCase().contains(_query) ?? false) ||
            (c.email?.toLowerCase().contains(_query) ?? false);
        if (!matches) return false;
      }
      switch (_filter) {
        case _CustomerFilter.all:
          return true;
        case _CustomerFilter.hasDue:
          return s.amountDue > 0.000001;
        case _CustomerFilter.hasCredit:
          return s.customer.creditBalance > 0.000001;
        case _CustomerFilter.active30:
          return s.lastSaleAt != null && s.lastSaleAt!.isAfter(cutoff);
      }
    }).toList();

    int compareDate(DateTime? a, DateTime? b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return b.compareTo(a);
    }

    filtered.sort((a, b) {
      switch (_sort) {
        case _CustomerSort.name:
          return a.customer.name
              .toLowerCase()
              .compareTo(b.customer.name.toLowerCase());
        case _CustomerSort.amountDue:
          final cmp = b.amountDue.compareTo(a.amountDue);
          if (cmp != 0) return cmp;
          return a.customer.name.compareTo(b.customer.name);
        case _CustomerSort.credit:
          return b.customer.creditBalance.compareTo(a.customer.creditBalance);
        case _CustomerSort.totalSpent:
          return b.customer.totalSpent.compareTo(a.customer.totalSpent);
        case _CustomerSort.lastSale:
          return compareDate(a.lastSaleAt, b.lastSaleAt);
      }
    });
    return filtered;
  }

  Future<void> _openProfile(
      BuildContext context, Customer customer) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForViewCustomers(),
      title: 'Customer Details',
      subtitle: 'Enter PIN to view customer details',
    );
    if (!allowed || !context.mounted) return;
    context.push('/customer/${customer.id}');
  }

  Future<void> _showRepaymentDialog(
      BuildContext context, CustomerSummary summary) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForEditCustomer(),
      title: 'Record Payment',
      subtitle: 'Enter PIN to record customer payment',
    );
    if (!allowed || !context.mounted) return;
    await showCustomerRepaymentDialog(
      context,
      ref: ref,
      customer: summary.customer,
      defaultAmount: summary.amountDue,
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final int customerCount;
  final double amountDue;
  final double storeCredit;
  final double bonuses;

  const _SummaryGrid({
    required this.customerCount,
    required this.amountDue,
    required this.storeCredit,
    required this.bonuses,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppStatTile(
                label: 'Customers',
                value: '$customerCount',
                icon: Icons.people_alt_outlined,
              ),
            ),
            const SizedBox(width: AppTokens.space2),
            Expanded(
              child: AppStatTile(
                label: 'Amount due',
                value: '\$${amountDue.toStringAsFixed(2)}',
                icon: Icons.report_outlined,
                tone: amountDue > 0.000001 ? extras.danger : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space2),
        Row(
          children: [
            Expanded(
              child: AppStatTile(
                label: 'Store credit out',
                value: '\$${storeCredit.toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet_outlined,
                tone: storeCredit > 0.000001 ? extras.success : null,
              ),
            ),
            const SizedBox(width: AppTokens.space2),
            Expanded(
              child: AppStatTile(
                label: 'Bonuses earned',
                value: '\$${bonuses.toStringAsFixed(2)}',
                icon: Icons.star_outline,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CustomerRow extends StatelessWidget {
  final CustomerSummary summary;
  final VoidCallback onTap;
  final VoidCallback? onRecordPayment;

  const _CustomerRow({
    required this.summary,
    required this.onTap,
    this.onRecordPayment,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final c = summary.customer;
    return AppPanel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space2, vertical: AppTokens.space2),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTokens.paperAlt,
            child: Text(
              c.name.isEmpty ? '?' : c.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(summary),
                  style: TextStyle(color: extras.muted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (summary.amountDue > 0.000001)
                _Pill(
                  text: 'Due \$${summary.amountDue.toStringAsFixed(2)}',
                  background: extras.danger.withValues(alpha: 0.12),
                  foreground: extras.danger,
                ),
              if (summary.amountDue > 0.000001 &&
                  c.creditBalance > 0.000001)
                const SizedBox(height: 4),
              if (c.creditBalance > 0.000001)
                _Pill(
                  text: 'Credit \$${c.creditBalance.toStringAsFixed(2)}',
                  background: extras.accentSoft,
                  foreground: extras.success,
                ),
              if (summary.amountDue <= 0.000001 &&
                  c.creditBalance <= 0.000001)
                Text(
                  '\$${c.totalSpent.toStringAsFixed(2)} lifetime',
                  style: TextStyle(color: extras.muted, fontSize: 12),
                ),
            ],
          ),
          if (onRecordPayment != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.payments_outlined),
              tooltip: 'Record payment',
              onPressed: onRecordPayment,
            ),
          ],
        ],
      ),
    );
  }

  String _subtitle(CustomerSummary s) {
    final parts = <String>[];
    if ((s.customer.phone ?? '').isNotEmpty) parts.add(s.customer.phone!);
    if (s.lastSaleAt != null) {
      parts.add('Last: ${_relative(s.lastSaleAt!)}');
    } else {
      parts.add('No sales yet');
    }
    if (s.unpaidCount > 0) {
      parts.add('${s.unpaidCount} unpaid');
    }
    return parts.join(' \u00B7 ');
  }

  String _relative(DateTime when) {
    final delta = DateTime.now().difference(when);
    if (delta.inMinutes < 60) return '${delta.inMinutes.clamp(0, 59)}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    if (delta.inDays < 60) return '${(delta.inDays / 7).floor()}w ago';
    return '${(delta.inDays / 30).floor()}mo ago';
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  const _Pill({
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        border: Border.all(color: extras.border, width: AppTokens.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Reprint each receipt whose paid / amount-due figures changed after
/// [recordCustomerPayment]. Skipped silently when the printing license is
/// disabled or there is nothing to print. Each printout is registered with
/// [ReceiptPrintService] so reprint numbering stays consistent with the
/// rest of the app.
Future<void> reprintRepaidReceipts(
  WidgetRef ref,
  List<Sale> updatedSales,
) async {
  if (updatedSales.isEmpty) return;
  if (!LicenseGate.isAllowed(FeatureKey.printing)) return;
  final printerService = ref.read(printerServiceProvider);
  final receiptSettings = ref.read(receiptSettingsProvider);
  final receiptPrintService = ReceiptPrintService();
  for (final sale in updatedSales) {
    try {
      final next = await receiptPrintService.getNextPrintNumber(sale.id);
      await printerService.printReceipt(
        sale,
        receiptSettings,
        printNumber: next,
      );
      await receiptPrintService.markPrinted(sale.id, printNumber: next);
    } catch (_) {
      // Swallow per-receipt errors so one failed printout doesn't block
      // the rest of the batch (e.g. printer offline, paper out).
    }
  }
}

String _buildPaymentSummary(CustomerPaymentResult result) {
  if (!result.didApplyAnything) {
    return 'No outstanding balance to apply this payment to.';
  }
  final cleared = result.updatedSales.where((s) => s.isPaidInFull).length;
  final partial = result.updatedSales.length - cleared;
  final parts = <String>[
    'Applied \$${result.totalApplied.toStringAsFixed(2)}',
  ];
  if (cleared > 0) parts.add('$cleared cleared');
  if (partial > 0) parts.add('$partial partial');
  if (result.leftover > 0.000001) {
    parts.add('\$${result.leftover.toStringAsFixed(2)} unapplied');
  }
  return parts.join(' \u00B7 ');
}

/// Shared "Record payment" dialog. Applies the entered amount FIFO across
/// the customer's unpaid sales via [SaleRepository.recordCustomerPayment]
/// and refreshes the providers + sync peers. When [saleId] is provided the
/// payment is restricted to that one receipt instead of fanning out across
/// the customer's full ledger.
Future<void> showCustomerRepaymentDialog(
  BuildContext context, {
  required WidgetRef ref,
  required Customer customer,
  required double defaultAmount,
  String? saleId,
}) async {
  final amountCtrl = TextEditingController(
    text: defaultAmount > 0 ? defaultAmount.toStringAsFixed(2) : '',
  );
  final noteCtrl = TextEditingController();
  final allUnpaid =
      await ref.read(customerUnpaidSalesProvider(customer.id).future);
  if (!context.mounted) return;
  final unpaid = saleId == null
      ? allUnpaid
      : allUnpaid.where((s) => s.id == saleId).toList();
  final extras = context.appExtras;

  await showDialog<void>(
    context: context,
    builder: (dctx) {
      double? typed = double.tryParse(amountCtrl.text);
      return StatefulBuilder(
        builder: (dctx, setLocal) {
          typed = double.tryParse(amountCtrl.text);
          final overpayment = (typed != null && typed! > defaultAmount)
              ? typed! - defaultAmount
              : 0.0;
          return AlertDialog(
            title: Text('Record Payment \u2014 ${customer.name}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Outstanding: \$${defaultAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: defaultAmount > 0
                          ? extras.danger
                          : extras.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount received',
                      prefixText: '\$',
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  if (overpayment > 0.000001) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Overpayment of \$${overpayment.toStringAsFixed(2)} will not be applied (no remaining due).',
                      style: TextStyle(color: extras.muted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                    ),
                  ),
                  if (unpaid.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      saleId != null
                          ? 'Applies to this receipt:'
                          : 'Will clear oldest first:',
                      style: TextStyle(color: extras.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    ...unpaid.take(3).map((s) => _OutstandingPreview(sale: s)),
                    if (unpaid.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+${unpaid.length - 3} more',
                          style:
                              TextStyle(color: extras.muted, fontSize: 12),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final v = double.tryParse(amountCtrl.text.trim());
                  if (v == null || v <= 0) {
                    Navigator.pop(dctx);
                    return;
                  }
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  Navigator.pop(dctx);
                  final result = await ref
                      .read(saleRepositoryProvider)
                      .recordCustomerPayment(
                        customerId: customer.id,
                        amount: v,
                        saleId: saleId,
                      );
                  SyncEventBus.instance
                      .emit(reason: 'customer_repayment');
                  await DataSyncTriggers.trigger(
                      reason: 'customer_repayment');
                  // Reprint each updated receipt so the customer leaves
                  // with paper proof of the new paid / amount-due totals.
                  await reprintRepaidReceipts(ref, result.updatedSales);
                  if (messenger != null) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(_buildPaymentSummary(result)),
                      ),
                    );
                  }
                },
                child: const Text('Record'),
              ),
            ],
          );
        },
      );
    },
  );
  amountCtrl.dispose();
  noteCtrl.dispose();
}

class _OutstandingPreview extends StatelessWidget {
  final Sale sale;
  const _OutstandingPreview({required this.sale});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final d = sale.createdAt;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$date \u00B7 \$${sale.total.toStringAsFixed(2)}',
              style: TextStyle(color: extras.muted, fontSize: 12),
            ),
          ),
          Text(
            'Due \$${sale.amountDue.toStringAsFixed(2)}',
            style: TextStyle(
              color: extras.danger,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
