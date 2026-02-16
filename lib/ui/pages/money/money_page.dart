import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/account_history_record.dart';
import '../../../models/money_account.dart';
import '../../../providers/money_provider.dart';
import '../../../repositories/money_repository.dart';
import '../../../services/data_sync_triggers.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

class MoneyPage extends ConsumerStatefulWidget {
  const MoneyPage({super.key});

  @override
  ConsumerState<MoneyPage> createState() => _MoneyPageState();
}

class _MoneyPageState extends ConsumerState<MoneyPage> {
  final NumberFormat _currencyFormat =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('MMM d, y - h:mm a');

  Future<void> _refreshData() async {
    ref.invalidate(moneyAccountsProvider);
    ref.invalidate(moneyTotalBalanceProvider);
    ref.invalidate(moneyHistoryProvider);
  }

  Future<void> _refreshAndSync(String reason) async {
    await _refreshData();
    await DataSyncTriggers.trigger(reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(moneyAccountsProvider);
    final totalBalanceAsync = ref.watch(moneyTotalBalanceProvider);
    final historyAsync = ref.watch(moneyHistoryProvider);

    return AppPageScaffold(
      title: 'Money',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refreshData,
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAccountFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New Account'),
      ),
      child: RefreshIndicator(
        onRefresh: _refreshData,
        child: accountsAsync.when(
          data: (accounts) {
            final totalBalance = totalBalanceAsync.valueOrNull ??
                accounts.fold<double>(
                    0, (sum, account) => sum + account.balance);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildSummaryPanel(
                  totalBalance: totalBalance,
                  accountCount: accounts.length,
                  transactionCount: historyAsync.valueOrNull?.length ?? 0,
                ),
                const SizedBox(height: AppTokens.space3),
                _buildAccountsHeader(),
                const SizedBox(height: AppTokens.space2),
                if (accounts.isEmpty)
                  _buildEmptyAccounts()
                else
                  ...accounts.map(
                    (account) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTokens.space2),
                      child: _buildAccountCard(account),
                    ),
                  ),
                const SizedBox(height: AppTokens.space3),
                _buildHistorySection(historyAsync),
                const SizedBox(height: AppTokens.space5),
              ],
            );
          },
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 220),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Failed to load money accounts.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppTokens.space1),
                    Text(
                      '$error',
                      style: const TextStyle(color: AppTokens.mutedText),
                    ),
                    const SizedBox(height: AppTokens.space2),
                    ElevatedButton.icon(
                      onPressed: _refreshData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryPanel({
    required double totalBalance,
    required int accountCount,
    required int transactionCount,
  }) {
    return AppPanel(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTokens.mutedText,
            ),
          ),
          const SizedBox(height: AppTokens.space2),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  label: 'Total Balance',
                  value: _currencyFormat.format(totalBalance),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Expanded(
                child: _buildSummaryMetric(
                  label: 'Accounts',
                  value: '$accountCount',
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Expanded(
                child: _buildSummaryMetric(
                  label: 'History Records',
                  value: '$transactionCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTokens.mutedText,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: AppTokens.space1),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildAccountsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Accounts',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        TextButton.icon(
          onPressed: () => _showAccountFormDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Create'),
        ),
      ],
    );
  }

  Widget _buildEmptyAccounts() {
    return AppPanel(
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.grey[600],
            size: 36,
          ),
          const SizedBox(height: AppTokens.space2),
          const Text(
            'No accounts yet',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTokens.space1),
          const Text(
            'Create your first account to start tracking balances and transaction history.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTokens.mutedText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(MoneyAccount account) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTokens.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if ((account.note ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          account.note!,
                          style: const TextStyle(
                            color: AppTokens.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Updated ${_dateFormat.format(account.updatedAt)}',
                      style: const TextStyle(
                        color: AppTokens.mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(account.balance),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: account.balance < 0
                          ? AppTokens.danger
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Manage account',
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showAccountFormDialog(account: account);
                          break;
                        case 'delete':
                          _confirmDeleteAccount(account);
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit account'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete account'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          Wrap(
            spacing: AppTokens.space1,
            runSpacing: AppTokens.space1,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _showBalanceDialog(account, isAdding: true),
                icon: const Icon(Icons.add),
                label: const Text('Add Money'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showBalanceDialog(account, isAdding: false),
                icon: const Icon(Icons.remove),
                label: const Text('Remove Money'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showAccountHistorySheet(account),
                icon: const Icon(Icons.history),
                label: const Text('View History'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(
      AsyncValue<List<AccountHistoryRecord>> historyAsync) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: AppTokens.space2),
          historyAsync.when(
            data: (records) {
              if (records.isEmpty) {
                return const Text(
                  'No transaction history yet.',
                  style: TextStyle(color: AppTokens.mutedText),
                );
              }
              return Column(
                children: records
                    .take(10)
                    .map(
                      (record) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppTokens.space1),
                        child: _buildHistoryTile(
                          record,
                          showAccountName: true,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Text(
              'Failed to load history: $error',
              style: const TextStyle(color: AppTokens.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(
    AccountHistoryRecord record, {
    required bool showAccountName,
  }) {
    final actionColor = _historyActionColor(record.action);
    final amountPrefix = record.isCredit
        ? '+'
        : (record.action == MoneyHistoryAction.moneyRemoved ? '-' : '');
    final amountText = '$amountPrefix${_currencyFormat.format(record.amount)}';

    return Container(
      padding: const EdgeInsets.all(AppTokens.space2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        border: Border.all(color: AppTokens.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _historyActionIcon(record.action),
              size: 18,
              color: actionColor,
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _historyActionLabel(record.action),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (showAccountName)
                  Text(
                    record.accountName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTokens.mutedText,
                    ),
                  ),
                Text(
                  'Balance ${_currencyFormat.format(record.balanceBefore)} -> '
                  '${_currencyFormat.format(record.balanceAfter)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTokens.mutedText,
                  ),
                ),
                if ((record.note ?? '').isNotEmpty)
                  Text(
                    record.note!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTokens.mutedText,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: record.isCredit
                      ? AppTokens.success
                      : (record.action == MoneyHistoryAction.moneyRemoved
                          ? AppTokens.danger
                          : AppTokens.mutedText),
                ),
              ),
              Text(
                _dateFormat.format(record.createdAt),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTokens.mutedText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAccountFormDialog({MoneyAccount? account}) async {
    final nameController = TextEditingController(text: account?.name ?? '');
    final noteController = TextEditingController(text: account?.note ?? '');
    final openingController = TextEditingController(
      text: account == null ? '0' : account.balance.toStringAsFixed(2),
    );
    final isEditing = account != null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Account' : 'Create Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Account Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppTokens.space2),
                if (!isEditing)
                  TextField(
                    controller: openingController,
                    decoration: const InputDecoration(
                      labelText: 'Opening Balance',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                if (!isEditing) const SizedBox(height: AppTokens.space2),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final repository = ref.read(moneyRepositoryProvider);
                final name = nameController.text.trim();
                final note = noteController.text.trim();

                late final MoneyActionResult result;
                if (isEditing) {
                  result = await repository.updateAccount(
                    accountId: account.id,
                    name: name,
                    note: note,
                  );
                } else {
                  final openingBalance =
                      double.tryParse(openingController.text.trim()) ?? 0;
                  result = await repository.createAccount(
                    name: name,
                    openingBalance: openingBalance,
                    note: note,
                  );
                }

                if (!mounted) {
                  return;
                }

                if (result.success) {
                  Navigator.of(dialogContext).pop();
                  await _refreshAndSync(
                    isEditing
                        ? 'money_account_updated'
                        : 'money_account_created',
                  );
                }
                _showResult(result);
              },
              child: Text(isEditing ? 'Save Changes' : 'Create Account'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBalanceDialog(
    MoneyAccount account, {
    required bool isAdding,
  }) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final title = isAdding ? 'Add Money' : 'Remove Money';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$title - ${account.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  helperText:
                      'Current balance: ${_currencyFormat.format(account.balance)}',
                  prefixText: '\$',
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppTokens.space2),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim()) ?? 0;
              final note = noteController.text.trim();
              final repository = ref.read(moneyRepositoryProvider);

              final result = isAdding
                  ? await repository.addMoney(
                      accountId: account.id,
                      amount: amount,
                      note: note,
                    )
                  : await repository.removeMoney(
                      accountId: account.id,
                      amount: amount,
                      note: note,
                    );

              if (!mounted) {
                return;
              }

              if (result.success) {
                Navigator.of(dialogContext).pop();
                await _refreshAndSync(
                  isAdding
                      ? 'money_added_to_account'
                      : 'money_removed_from_account',
                );
              }
              _showResult(result);
            },
            child: Text(title),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(MoneyAccount account) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          'Delete "${account.name}"?\n'
          'Current balance: ${_currencyFormat.format(account.balance)}\n'
          'History records will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final repository = ref.read(moneyRepositoryProvider);
              final result = await repository.deleteAccount(account.id);
              if (!mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
              if (result.success) {
                await _refreshAndSync('money_account_deleted');
              }
              _showResult(result);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTokens.danger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAccountHistorySheet(MoneyAccount account) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.8;
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Consumer(
              builder: (context, ref, child) {
                final historyAsync =
                    ref.watch(accountMoneyHistoryProvider(account.id));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.space3,
                        AppTokens.space3,
                        AppTokens.space3,
                        AppTokens.space2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${account.name} History',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: historyAsync.when(
                        data: (records) {
                          if (records.isEmpty) {
                            return const Center(
                              child: Text(
                                'No history records yet.',
                                style: TextStyle(color: AppTokens.mutedText),
                              ),
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppTokens.space3,
                              0,
                              AppTokens.space3,
                              AppTokens.space3,
                            ),
                            itemCount: records.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppTokens.space1),
                            itemBuilder: (context, index) {
                              return _buildHistoryTile(
                                records[index],
                                showAccountName: false,
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) => Center(
                          child: Text(
                            'Failed to load history: $error',
                            style: const TextStyle(color: AppTokens.danger),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showResult(MoneyActionResult result) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? AppTokens.success : AppTokens.danger,
      ),
    );
  }

  IconData _historyActionIcon(MoneyHistoryAction action) {
    switch (action) {
      case MoneyHistoryAction.accountCreated:
        return Icons.add_card_outlined;
      case MoneyHistoryAction.accountUpdated:
        return Icons.edit_outlined;
      case MoneyHistoryAction.accountDeleted:
        return Icons.delete_outline;
      case MoneyHistoryAction.moneyAdded:
        return Icons.arrow_downward;
      case MoneyHistoryAction.moneyRemoved:
        return Icons.arrow_upward;
    }
  }

  String _historyActionLabel(MoneyHistoryAction action) {
    switch (action) {
      case MoneyHistoryAction.accountCreated:
        return 'Account Created';
      case MoneyHistoryAction.accountUpdated:
        return 'Account Updated';
      case MoneyHistoryAction.accountDeleted:
        return 'Account Deleted';
      case MoneyHistoryAction.moneyAdded:
        return 'Money Added';
      case MoneyHistoryAction.moneyRemoved:
        return 'Money Removed';
    }
  }

  Color _historyActionColor(MoneyHistoryAction action) {
    switch (action) {
      case MoneyHistoryAction.accountCreated:
        return AppTokens.success;
      case MoneyHistoryAction.accountUpdated:
        return AppTokens.warning;
      case MoneyHistoryAction.accountDeleted:
        return AppTokens.danger;
      case MoneyHistoryAction.moneyAdded:
        return AppTokens.success;
      case MoneyHistoryAction.moneyRemoved:
        return AppTokens.danger;
    }
  }
}
