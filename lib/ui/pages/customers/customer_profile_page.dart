import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../helpers/pin_protection.dart';
import '../../../models/customer.dart';
import '../../../models/customer_credit_entry.dart';
import '../../../models/sale.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/sale_provider.dart';
import '../../../services/bonus_engine.dart';
import '../../../services/data_sync_triggers.dart';
import '../../../services/pin_service.dart';
import '../../../services/sync_event_bus.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_section_header.dart';
import '../../design_system/widgets/app_stat_tile.dart';
import 'customer_list_page.dart';
import 'customer_management_page.dart';

class CustomerProfilePage extends ConsumerWidget {
  final String customerId;

  const CustomerProfilePage({
    super.key,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerByIdProvider(customerId));
    final salesAsync = ref.watch(salesProvider);
    final entriesAsync = ref.watch(creditEntriesForCustomerProvider(customerId));
    final unpaidAsync = ref.watch(customerUnpaidSalesProvider(customerId));
    final amountDueAsync = ref.watch(customerAmountDueProvider(customerId));
    final extras = context.appExtras;

    return AppPageScaffold(
      title: 'Customer Profile',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () async {
            final allowed = await PinProtection.requirePinIfNeeded(
              context,
              isRequired: () => PinService().isPinRequiredForEditCustomer(),
              title: 'Edit Customer',
              subtitle: 'Enter PIN to edit customer',
            );
            if (!allowed || !context.mounted) return;
            final customer = customerAsync.asData?.value;
            if (customer == null) return;
            await showCustomerEditorSheet(context,
                ref: ref, existing: customer);
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final customer = customerAsync.asData?.value;
            if (customer == null) return;
            final allowed = await PinProtection.requirePinIfNeeded(
              context,
              isRequired: () => PinService().isPinRequiredForDeleteCustomer(),
              title: 'Delete Customer',
              subtitle: 'Enter PIN to delete customer',
            );
            if (!allowed || !context.mounted) return;
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dctx) => AlertDialog(
                title: const Text('Delete Customer?'),
                content: Text(
                    'Remove ${customer.name}? Their credit balance and history will be lost.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dctx, true),
                      child: const Text('Delete')),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            await ref
                .read(customerRepositoryProvider)
                .deleteCustomer(customer.id);
            SyncEventBus.instance.emit(reason: 'customer_deleted');
            DataSyncTriggers.trigger(reason: 'customer_deleted');
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        const SizedBox(width: 6),
      ],
      scrollable: true,
      child: customerAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppTokens.space3),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(AppTokens.space3),
          child: Text('Error: $e'),
        ),
        data: (customer) {
          if (customer == null) {
            return const Padding(
              padding: EdgeInsets.all(AppTokens.space3),
              child: Text('Customer not found.'),
            );
          }
          final customerSales = salesAsync
                  .asData?.value
                  .where((s) => s.customerId == customer.id)
                  .toList() ??
              [];
          final entries = entriesAsync.asData?.value ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderPanel(customer: customer),
              const SizedBox(height: AppTokens.space3),
              Row(
                children: [
                  Expanded(
                    child: AppStatTile(
                      label: 'Purchases',
                      value: '${customer.totalPurchases}',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  Expanded(
                    child: AppStatTile(
                      label: 'Total spent',
                      value: '\$${customer.totalSpent.toStringAsFixed(2)}',
                      icon: Icons.attach_money_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space4),
              const AppSectionHeader(title: 'Credit & Bonus'),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _KvRow(
                      label: 'Current balance',
                      value: '\$${customer.creditBalance.toStringAsFixed(2)}',
                      valueColor: customer.creditBalance > 0
                          ? extras.success
                          : null,
                      valueBold: true,
                    ),
                    const SizedBox(height: 6),
                    _KvRow(
                      label: 'Bonuses earned',
                      value:
                          '\$${customer.totalBonusEarned.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 6),
                    _KvRow(
                      label: 'Credit redeemed',
                      value:
                          '\$${customer.totalCreditRedeemed.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: AppTokens.space2),
                    OutlinedButton.icon(
                      onPressed: () => _showAdjustDialog(context, ref, customer),
                      icon: const Icon(Icons.tune),
                      label: const Text('Manual adjustment'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space4),
              const AppSectionHeader(title: 'Amount Due'),
              _AmountDuePanel(
                customer: customer,
                amountDue: amountDueAsync.asData?.value ?? 0,
                unpaid: unpaidAsync.asData?.value ?? const [],
                onRecordPayment: () async {
                  final allowed = await PinProtection.requirePinIfNeeded(
                    context,
                    isRequired: () =>
                        PinService().isPinRequiredForEditCustomer(),
                    title: 'Record Payment',
                    subtitle: 'Enter PIN to record customer payment',
                  );
                  if (!allowed || !context.mounted) return;
                  await showCustomerRepaymentDialog(
                    context,
                    ref: ref,
                    customer: customer,
                    defaultAmount: amountDueAsync.asData?.value ?? 0,
                  );
                },
              ),
              const SizedBox(height: AppTokens.space4),
              const AppSectionHeader(title: 'Spending History'),
              AppPanel(
                child: customerSales.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppTokens.space2),
                        child: Text('No purchases yet.',
                            style: TextStyle(color: extras.muted)),
                      )
                    : Column(
                        children: customerSales
                            .take(20)
                            .map((s) => _SaleRow(sale: s))
                            .toList(),
                      ),
              ),
              const SizedBox(height: AppTokens.space4),
              const AppSectionHeader(title: 'Credit History'),
              AppPanel(
                child: entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppTokens.space2),
                        child: Text('No credit activity yet.',
                            style: TextStyle(color: extras.muted)),
                      )
                    : Column(
                        children: entries
                            .take(30)
                            .map((e) => _CreditRow(entry: e))
                            .toList(),
                      ),
              ),
              if ((customer.address ?? '').isNotEmpty ||
                  (customer.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: AppTokens.space4),
                const AppSectionHeader(title: 'Details'),
                AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((customer.address ?? '').isNotEmpty) ...[
                        Text('Address',
                            style: TextStyle(
                                color: extras.muted, fontSize: 12)),
                        Text(customer.address!),
                        const SizedBox(height: 8),
                      ],
                      if ((customer.notes ?? '').isNotEmpty) ...[
                        Text('Notes',
                            style: TextStyle(
                                color: extras.muted, fontSize: 12)),
                        Text(customer.notes!),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppTokens.space4),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAdjustDialog(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final allowed = await PinProtection.requirePinIfNeeded(
      context,
      isRequired: () => PinService().isPinRequiredForEditCustomer(),
      title: 'Adjust Credit',
      subtitle: 'Enter PIN to adjust customer credit',
    );
    if (!allowed || !context.mounted) return;
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Manual credit adjustment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Amount (positive adds, negative deducts)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(amountCtrl.text.trim());
              if (v == null || v == 0) {
                Navigator.pop(dctx);
                return;
              }
              Navigator.pop(dctx, v);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await BonusEngine().recordManualAdjustment(
      customerId: customer.id,
      amount: result,
      reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
    );
    SyncEventBus.instance.emit(reason: 'customer_credit_adjusted');
    DataSyncTriggers.trigger(reason: 'customer_credit_adjusted');
  }
}

class _HeaderPanel extends StatelessWidget {
  final Customer customer;
  const _HeaderPanel({required this.customer});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return AppPanel(
      emphasized: true,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTokens.paper,
            child: Text(
              customer.name.isEmpty
                  ? '?'
                  : customer.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 22,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                if ((customer.phone ?? '').isNotEmpty)
                  Text(customer.phone!,
                      style: TextStyle(color: extras.muted)),
                if ((customer.email ?? '').isNotEmpty)
                  Text(customer.email!,
                      style: TextStyle(color: extras.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBold;
  const _KvRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: extras.muted)),
        Text(
          value,
          style: TextStyle(
            fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _SaleRow extends StatelessWidget {
  final Sale sale;
  const _SaleRow({required this.sale});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final d = sale.createdAt;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final hasDue = sale.amountDue > 0.000001;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('\$${sale.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (hasDue) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: extras.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTokens.radiusS),
                border:
                    Border.all(color: extras.danger.withValues(alpha: 0.4)),
              ),
              child: Text(
                'DUE \$${sale.amountDue.toStringAsFixed(2)}',
                style: TextStyle(
                  color: extras.danger,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${sale.items.length} items - ${sale.paymentMethod}'
        '${sale.bonusEarned > 0 ? ' - +\$${sale.bonusEarned.toStringAsFixed(2)} bonus' : ''}'
        '${sale.creditApplied > 0 ? ' - -\$${sale.creditApplied.toStringAsFixed(2)} credit' : ''}',
        style: TextStyle(color: extras.muted, fontSize: 12),
      ),
      trailing: Text('$date\n$time',
          textAlign: TextAlign.right,
          style: TextStyle(color: extras.muted, fontSize: 12)),
    );
  }
}

class _AmountDuePanel extends StatelessWidget {
  final Customer customer;
  final double amountDue;
  final List<Sale> unpaid;
  final VoidCallback onRecordPayment;

  const _AmountDuePanel({
    required this.customer,
    required this.amountDue,
    required this.unpaid,
    required this.onRecordPayment,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final hasDue = amountDue > 0.000001;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Outstanding', style: TextStyle(color: extras.muted)),
              Text(
                '\$${amountDue.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: hasDue ? extras.danger : null,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          if (unpaid.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space2),
            ...unpaid.take(5).map((s) => _UnpaidSaleRow(sale: s)),
            if (unpaid.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${unpaid.length - 5} more unpaid',
                  style: TextStyle(color: extras.muted, fontSize: 12),
                ),
              ),
          ] else ...[
            const SizedBox(height: AppTokens.space1),
            Text(
              'No unpaid sales.',
              style: TextStyle(color: extras.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: AppTokens.space2),
          FilledButton.icon(
            onPressed: hasDue ? onRecordPayment : null,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Record payment'),
          ),
        ],
      ),
    );
  }
}

class _UnpaidSaleRow extends StatelessWidget {
  final Sale sale;
  const _UnpaidSaleRow({required this.sale});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final d = sale.createdAt;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${sale.total.toStringAsFixed(2)} \u00B7 ${sale.paymentMethod}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$date \u00B7 paid \$${sale.amountPaid.toStringAsFixed(2)}',
                  style: TextStyle(color: extras.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            'Due \$${sale.amountDue.toStringAsFixed(2)}',
            style: TextStyle(
              color: extras.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  final CustomerCreditEntry entry;
  const _CreditRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final isCredit = entry.amount >= 0;
    final icon = switch (entry.type) {
      CustomerCreditEntryType.bonus => Icons.star_border,
      CustomerCreditEntryType.redeem => Icons.shopping_bag_outlined,
      CustomerCreditEntryType.manualAdjustment => Icons.tune,
    };
    final label = switch (entry.type) {
      CustomerCreditEntryType.bonus => 'Bonus earned',
      CustomerCreditEntryType.redeem => 'Credit redeemed',
      CustomerCreditEntryType.manualAdjustment => 'Manual adjustment',
    };
    final d = entry.createdAt;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon,
          color: isCredit ? extras.success : extras.danger, size: 20),
      title: Text(label),
      subtitle: Text(
        entry.reason ?? (entry.saleId != null ? 'Sale ${entry.saleId}' : ''),
        style: TextStyle(color: extras.muted, fontSize: 12),
      ),
      trailing: Text(
        '${isCredit ? '+' : '-'}\$${entry.amount.abs().toStringAsFixed(2)}\n$date',
        textAlign: TextAlign.right,
        style: TextStyle(
          color: isCredit ? extras.success : extras.danger,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
