import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/customer.dart';
import '../../../../providers/customer_provider.dart';
import '../../../design_system/app_theme_extensions.dart';
import '../../../design_system/app_tokens.dart';
import '../../../design_system/widgets/app_panel.dart';
import '../../../design_system/widgets/app_search_field.dart';
import '../../customers/customer_list_page.dart';

/// Bottom sheet for selecting an existing customer or creating a new one.
/// Returns the chosen [Customer], or null if cancelled.
Future<Customer?> showCustomerPickerSheet(BuildContext context) async {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CustomerPickerSheet(),
  );
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
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
    final height = MediaQuery.of(context).size.height * 0.75;

    return Padding(
      padding: EdgeInsets.only(
        left: AppTokens.space3,
        right: AppTokens.space3,
        top: AppTokens.space2,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTokens.space2,
      ),
      child: SizedBox(
        height: height,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Customer',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final created = await showCustomerEditorSheet(context,
                        ref: ref);
                    if (created != null && mounted) {
                      Navigator.pop(context, created);
                    }
                  },
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('New'),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space2),
            AppSearchField(
              controller: _searchController,
              hintText: 'Search by name, phone, email...',
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
                            ? 'No saved customers yet.\nTap "New" to add one.'
                            : 'No matching customers.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: extras.muted),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppTokens.space2),
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      return AppPanel(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => Navigator.pop(context, c),
                          leading: CircleAvatar(
                            backgroundColor: AppTokens.paperAlt,
                            child: Text(
                              c.name.isEmpty
                                  ? '?'
                                  : c.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(c.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            [
                              if ((c.phone ?? '').isNotEmpty) c.phone!,
                              if ((c.email ?? '').isNotEmpty) c.email!,
                            ].join(' - '),
                            style: TextStyle(
                                color: extras.muted, fontSize: 12),
                          ),
                          trailing: c.creditBalance > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: extras.accentSoft,
                                    borderRadius: BorderRadius.circular(
                                        AppTokens.radiusM),
                                    border: Border.all(
                                        color: extras.border,
                                        width: AppTokens.border),
                                  ),
                                  child: Text(
                                    '\$${c.creditBalance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: extras.success,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
}
