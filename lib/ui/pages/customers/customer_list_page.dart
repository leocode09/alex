import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../helpers/pin_protection.dart';
import '../../../models/customer.dart';
import '../../../providers/customer_provider.dart';
import '../../../services/data_sync_triggers.dart';
import '../../../services/pin_service.dart';
import '../../../services/sync_event_bus.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_search_field.dart';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final customersAsync = ref.watch(customersProvider);

    return AppPageScaffold(
      title: 'Customers',
      floatingActionButton: FloatingActionButton(
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
        child: const Icon(Icons.add),
      ),
      child: Column(
        children: [
          AppSearchField(
            controller: _searchController,
            hintText: 'Search customers...',
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: AppTokens.space2),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (customers) {
                final filtered = _filter(customers);
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      customers.isEmpty
                          ? 'No customers yet. Tap + to add one.'
                          : 'No matching customers.',
                      style: TextStyle(color: extras.muted),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTokens.space2),
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    return AppPanel(
                      child: ListTile(
                        onTap: () async {
                          if (await PinProtection.requirePinIfNeeded(
                            context,
                            isRequired: () =>
                                PinService().isPinRequiredForViewCustomers(),
                            title: 'Customer Details',
                            subtitle: 'Enter PIN to view customer details',
                          )) {
                            if (!context.mounted) return;
                            context.push('/customers/${c.id}');
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: AppTokens.paperAlt,
                          child: Text(
                            c.name.isEmpty ? '?' : c.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _subtitleFor(c),
                          style: TextStyle(color: extras.muted, fontSize: 12),
                        ),
                        trailing: c.creditBalance > 0
                            ? _CreditChip(amount: c.creditBalance)
                            : const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Customer> _filter(List<Customer> customers) {
    if (_query.isEmpty) return customers;
    return customers.where((c) {
      return c.name.toLowerCase().contains(_query) ||
          (c.phone?.toLowerCase().contains(_query) ?? false) ||
          (c.email?.toLowerCase().contains(_query) ?? false);
    }).toList();
  }

  String _subtitleFor(Customer c) {
    final parts = <String>['${c.totalPurchases} purchases'];
    if ((c.phone ?? '').isNotEmpty) parts.add(c.phone!);
    return parts.join(' - ');
  }
}

class _CreditChip extends StatelessWidget {
  final double amount;
  const _CreditChip({required this.amount});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: extras.accentSoft,
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        border: Border.all(color: extras.border, width: AppTokens.border),
      ),
      child: Text(
        '\$${amount.toStringAsFixed(2)}',
        style: TextStyle(
          color: extras.success,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Shared bottom-sheet editor for creating or updating a customer. Returns
/// the saved [Customer] on success, or null if cancelled.
Future<Customer?> showCustomerEditorSheet(
  BuildContext context, {
  required WidgetRef ref,
  Customer? existing,
}) async {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _CustomerEditorSheet(ref: ref, existing: existing),
  );
}

class _CustomerEditorSheet extends StatefulWidget {
  final WidgetRef ref;
  final Customer? existing;
  const _CustomerEditorSheet({required this.ref, this.existing});

  @override
  State<_CustomerEditorSheet> createState() => _CustomerEditorSheetState();
}

class _CustomerEditorSheetState extends State<_CustomerEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: AppTokens.space3,
        right: AppTokens.space3,
        top: AppTokens.space2,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTokens.space3,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Edit Customer' : 'Add Customer',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppTokens.space3),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppTokens.space2),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppTokens.space2),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppTokens.space2),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
            ),
            const SizedBox(height: AppTokens.space2),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: AppTokens.space3),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppTokens.space2),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving
                        ? 'Saving...'
                        : (isEdit ? 'Save' : 'Add')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = widget.ref.read(customerRepositoryProvider);
    final now = DateTime.now();
    final existing = widget.existing;
    final customer = existing == null
        ? Customer(
            id: 'cust_${const Uuid().v4()}',
            name: name,
            phone: _nullIfEmpty(_phone.text),
            email: _nullIfEmpty(_email.text),
            address: _nullIfEmpty(_address.text),
            notes: _nullIfEmpty(_notes.text),
            joinDate: now,
            updatedAt: now,
          )
        : existing.copyWith(
            name: name,
            phone: _nullIfEmpty(_phone.text),
            email: _nullIfEmpty(_email.text),
            address: _nullIfEmpty(_address.text),
            notes: _nullIfEmpty(_notes.text),
            updatedAt: now,
          );
    final ok = existing == null
        ? await repo.insertCustomer(customer)
        : await repo.updateCustomer(customer);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save customer')),
      );
      return;
    }
    SyncEventBus.instance.publish(const SyncEvent(reason: 'customer_saved'));
    unawaitedTrigger();
    if (mounted) {
      Navigator.pop(context, customer);
    }
  }

  String? _nullIfEmpty(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  void unawaitedTrigger() {
    DataSyncTriggers.trigger(reason: 'customer_saved');
  }
}
