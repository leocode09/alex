import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/bonus_rule_service.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

class BonusRulePage extends ConsumerStatefulWidget {
  const BonusRulePage({super.key});

  @override
  ConsumerState<BonusRulePage> createState() => _BonusRulePageState();
}

class _BonusRulePageState extends ConsumerState<BonusRulePage> {
  late final TextEditingController _thresholdCtrl;
  late final TextEditingController _bonusCtrl;
  late final TextEditingController _windowCtrl;
  bool _enabled = true;
  bool _dirty = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _thresholdCtrl = TextEditingController();
    _bonusCtrl = TextEditingController();
    _windowCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _thresholdCtrl.dispose();
    _bonusCtrl.dispose();
    _windowCtrl.dispose();
    super.dispose();
  }

  void _hydrate(BonusRule rule) {
    if (_loaded) return;
    _loaded = true;
    _enabled = rule.enabled;
    _thresholdCtrl.text = rule.thresholdAmount.toStringAsFixed(2);
    _bonusCtrl.text = rule.bonusAmount.toStringAsFixed(2);
    _windowCtrl.text = rule.windowDays.toString();
  }

  Future<void> _save() async {
    final threshold = double.tryParse(_thresholdCtrl.text.trim()) ?? 0;
    final bonus = double.tryParse(_bonusCtrl.text.trim()) ?? 0;
    final window = int.tryParse(_windowCtrl.text.trim()) ?? 0;
    if (threshold <= 0 || bonus <= 0 || window <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All values must be greater than zero')),
      );
      return;
    }
    await ref.read(bonusRuleProvider.notifier).update(BonusRule(
          enabled: _enabled,
          windowDays: window,
          thresholdAmount: threshold,
          bonusAmount: bonus,
        ));
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reward rule saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rule = ref.watch(bonusRuleProvider);
    _hydrate(rule);
    final extras = context.appExtras;

    return AppPageScaffold(
      title: 'Customer Rewards',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPanel(
            emphasized: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonus rule',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'When a customer\'s spending reaches the threshold within the window, they automatically earn the bonus as credit.',
                  style: TextStyle(color: extras.muted, fontSize: 12),
                ),
                const SizedBox(height: AppTokens.space3),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable rewards'),
                  value: _enabled,
                  onChanged: (v) {
                    setState(() {
                      _enabled = v;
                      _dirty = true;
                    });
                  },
                ),
                const SizedBox(height: AppTokens.space2),
                TextField(
                  controller: _thresholdCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Spend threshold',
                    prefixText: '\$',
                    helperText:
                        'Total customer spending required within the window to earn a bonus',
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                const SizedBox(height: AppTokens.space2),
                TextField(
                  controller: _bonusCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Bonus amount',
                    prefixText: '\$',
                    helperText: 'Credit added to the customer\'s balance',
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                const SizedBox(height: AppTokens.space2),
                TextField(
                  controller: _windowCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Window (days)',
                    helperText:
                        'Rolling spend window, counted back from each sale',
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          FilledButton.icon(
            onPressed: _dirty ? _save : null,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
          const SizedBox(height: AppTokens.space3),
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Example',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(
                  _exampleLine(),
                  style: TextStyle(color: extras.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
        ],
      ),
    );
  }

  String _exampleLine() {
    final threshold = double.tryParse(_thresholdCtrl.text.trim()) ?? 0;
    final bonus = double.tryParse(_bonusCtrl.text.trim()) ?? 0;
    final window = int.tryParse(_windowCtrl.text.trim()) ?? 0;
    if (threshold <= 0 || bonus <= 0 || window <= 0) {
      return 'Enter all values to see an example.';
    }
    return 'If a customer spends \$${threshold.toStringAsFixed(2)} '
        'within $window day${window == 1 ? '' : 's'}, they automatically '
        'earn \$${bonus.toStringAsFixed(2)} of credit they can redeem on a future purchase.';
  }
}
