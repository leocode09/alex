import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/account_state.dart';
import '../../../providers/account_provider.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_search_field.dart';

/// Staff onboarding screen: search the directory of approved
/// businesses, pick one, enter the staff member's display name, and
/// submit the join request to the owner.
class JoinBusinessPage extends ConsumerStatefulWidget {
  const JoinBusinessPage({super.key});

  @override
  ConsumerState<JoinBusinessPage> createState() => _JoinBusinessPageState();
}

class _JoinBusinessPageState extends ConsumerState<JoinBusinessPage> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  bool _submitting = false;
  List<BusinessSummary> _results = const [];
  BusinessSummary? _selected;

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    final next = v.trim();
    if (next == _query) return;
    _query = next;
    _debounce?.cancel();
    if (next.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final service = ref.read(accountServiceProvider);
      final results = await service.searchApprovedBusinesses(next);
      if (!mounted || _query != next) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    });
  }

  void _selectBusiness(BusinessSummary b) {
    setState(() {
      _selected = b;
      _searchController.text = b.name;
      _query = b.name;
      _results = const [];
    });
  }

  void _clearSelection() {
    setState(() {
      _selected = null;
    });
  }

  Future<void> _submit() async {
    final selected = _selected;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a business from the list.')),
      );
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your name first.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final service = ref.read(accountServiceProvider);
      final result = await service.submitStaffJoinRequest(
        shopId: selected.id,
        displayName: name,
        phoneNumber: _phoneController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      if (result.success) {
        context.go('/pending-approval');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final theme = Theme.of(context);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text(
          'Join a business',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      padding: const EdgeInsets.all(AppTokens.space3),
      child: ListView(
        children: [
          AppPanel(
            padding: const EdgeInsets.all(AppTokens.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find your business',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Search by business name. The owner will see your '
                  'request and approve or reject it.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: extras.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          AppSearchField(
            controller: _searchController,
            hintText: 'Search businesses by name',
            onChanged: _onQueryChanged,
          ),
          const SizedBox(height: AppTokens.space2),
          if (_selected != null) _buildSelectedCard(theme, extras),
          if (_selected == null && _searching)
            const Padding(
              padding: EdgeInsets.all(AppTokens.space3),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_selected == null &&
              !_searching &&
              _query.isNotEmpty &&
              _results.isEmpty)
            AppPanel(
              padding: const EdgeInsets.all(AppTokens.space3),
              child: Text(
                'No approved businesses match "$_query". Check the '
                'spelling, or ask the owner for the exact name.',
                style: TextStyle(color: extras.muted),
              ),
            ),
          if (_selected == null && _results.isNotEmpty)
            ..._results.map((b) => _ResultTile(
                  business: b,
                  onSelect: () => _selectBusiness(b),
                )),
          const SizedBox(height: AppTokens.space3),
          if (_selected != null) _buildStaffForm(theme),
        ],
      ),
    );
  }

  Widget _buildSelectedCard(ThemeData theme, AppThemeExtras extras) {
    final b = _selected!;
    return AppPanel(
      emphasized: true,
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 20, color: extras.success),
              const SizedBox(width: 8),
              Text(
                'Selected business',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: extras.muted,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearSelection,
                child: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space1),
          Text(
            b.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (b.code.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Code ${b.code}',
              style: TextStyle(
                color: extras.muted,
                fontFamily: 'IBMPlexMono',
              ),
            ),
          ],
          if (b.ownerName != null && b.ownerName!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Owner ${b.ownerName!.trim()}',
              style: TextStyle(color: extras.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStaffForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your details',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppTokens.space2),
        TextField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Your name',
            hintText: 'How the owner will recognize you',
          ),
        ),
        const SizedBox(height: AppTokens.space2),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Phone (optional)',
          ),
          onSubmitted: (_) => _submitting ? null : _submit(),
        ),
        const SizedBox(height: AppTokens.space3),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send join request'),
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final BusinessSummary business;
  final VoidCallback onSelect;

  const _ResultTile({required this.business, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return AppPanel(
      onTap: onSelect,
      margin: const EdgeInsets.only(bottom: AppTokens.space1),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space2,
        vertical: AppTokens.space2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                if (business.code.isNotEmpty)
                  Text(
                    'Code ${business.code}',
                    style: TextStyle(
                      color: extras.muted,
                      fontFamily: 'IBMPlexMono',
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
