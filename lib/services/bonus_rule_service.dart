import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BonusRule {
  final bool enabled;
  final int windowDays;
  final double thresholdAmount;
  final double bonusAmount;

  const BonusRule({
    required this.enabled,
    required this.windowDays,
    required this.thresholdAmount,
    required this.bonusAmount,
  });

  static const BonusRule defaults = BonusRule(
    enabled: true,
    windowDays: 7,
    thresholdAmount: 2000.0,
    bonusAmount: 5.0,
  );

  BonusRule copyWith({
    bool? enabled,
    int? windowDays,
    double? thresholdAmount,
    double? bonusAmount,
  }) {
    return BonusRule(
      enabled: enabled ?? this.enabled,
      windowDays: windowDays ?? this.windowDays,
      thresholdAmount: thresholdAmount ?? this.thresholdAmount,
      bonusAmount: bonusAmount ?? this.bonusAmount,
    );
  }
}

class BonusRuleService {
  static const String _kEnabled = 'bonus_rule_enabled';
  static const String _kWindowDays = 'bonus_rule_window_days';
  static const String _kThreshold = 'bonus_rule_threshold';
  static const String _kBonus = 'bonus_rule_bonus';

  Future<BonusRule> load() async {
    final prefs = await SharedPreferences.getInstance();
    return BonusRule(
      enabled: prefs.getBool(_kEnabled) ?? BonusRule.defaults.enabled,
      windowDays: prefs.getInt(_kWindowDays) ?? BonusRule.defaults.windowDays,
      thresholdAmount:
          prefs.getDouble(_kThreshold) ?? BonusRule.defaults.thresholdAmount,
      bonusAmount: prefs.getDouble(_kBonus) ?? BonusRule.defaults.bonusAmount,
    );
  }

  Future<void> save(BonusRule rule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, rule.enabled);
    await prefs.setInt(_kWindowDays, rule.windowDays);
    await prefs.setDouble(_kThreshold, rule.thresholdAmount);
    await prefs.setDouble(_kBonus, rule.bonusAmount);
  }
}

class BonusRuleNotifier extends StateNotifier<BonusRule> {
  BonusRuleNotifier(this._service) : super(BonusRule.defaults) {
    _load();
  }

  final BonusRuleService _service;

  Future<void> _load() async {
    state = await _service.load();
  }

  Future<void> update(BonusRule rule) async {
    await _service.save(rule);
    state = rule;
  }

  Future<void> refresh() => _load();
}

final bonusRuleServiceProvider =
    Provider<BonusRuleService>((ref) => BonusRuleService());

final bonusRuleProvider =
    StateNotifierProvider<BonusRuleNotifier, BonusRule>((ref) {
  return BonusRuleNotifier(ref.watch(bonusRuleServiceProvider));
});
