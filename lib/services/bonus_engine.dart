import '../models/customer.dart';
import '../models/customer_credit_entry.dart';
import '../models/sale.dart';
import '../repositories/customer_credit_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/sale_repository.dart';
import 'bonus_rule_service.dart';

/// Result of applying a sale's customer-side side-effects: bonus grant,
/// spending total bump, and the credit balance / total spending after the
/// sale. Returned so the caller can persist snapshots onto the Sale row.
class BonusApplicationResult {
  final Customer updatedCustomer;
  final double bonusEarned;
  final double totalSpentAfter;
  final double creditBalanceAfter;

  const BonusApplicationResult({
    required this.updatedCustomer,
    required this.bonusEarned,
    required this.totalSpentAfter,
    required this.creditBalanceAfter,
  });
}

/// Applies the spend-within-window bonus rule and keeps customer running
/// totals in sync with completed sales. Invoked after a sale is inserted
/// (or updated). Bonus is granted at most once per threshold-crossing within
/// the rolling window.
class BonusEngine {
  BonusEngine({
    CustomerRepository? customerRepository,
    CustomerCreditRepository? creditRepository,
    SaleRepository? saleRepository,
    BonusRuleService? ruleService,
  })  : _customerRepo = customerRepository ?? CustomerRepository(),
        _creditRepo = creditRepository ?? CustomerCreditRepository(),
        _saleRepo = saleRepository ?? SaleRepository(),
        _ruleService = ruleService ?? BonusRuleService();

  final CustomerRepository _customerRepo;
  final CustomerCreditRepository _creditRepo;
  final SaleRepository _saleRepo;
  final BonusRuleService _ruleService;

  /// Apply customer totals + bonus rule for a freshly inserted sale.
  /// - Bumps `Customer.totalPurchases` and `totalSpent` by the sale's
  ///   pre-credit net (`sale.total + sale.creditApplied`).
  /// - Persists any redemption entry if [sale.creditApplied] > 0 (the caller
  ///   is expected to have already subtracted from `creditBalance`; this
  ///   method just records the ledger line when [recordRedemption] is true).
  /// - Computes bonus grants based on the rule.
  /// - Returns snapshots so the sale row can be stamped with
  ///   `customerTotalSpentAfter`, `customerCreditBalanceAfter`, `bonusEarned`.
  Future<BonusApplicationResult?> applyForNewSale({
    required Sale sale,
    required Customer customer,
    bool recordRedemption = true,
  }) async {
    final now = DateTime.now();
    final preCreditNet = sale.total + sale.creditApplied;

    // 1. Record redemption ledger line (credit already debited by caller).
    if (recordRedemption && sale.creditApplied > 0) {
      await _creditRepo.insertEntry(
        CustomerCreditEntry(
          id: 'credit-${sale.id}',
          customerId: customer.id,
          type: CustomerCreditEntryType.redeem,
          amount: -sale.creditApplied,
          saleId: sale.id,
          reason: 'Applied at checkout',
          createdAt: now,
        ),
      );
    }

    // 2. Bump running totals.
    var updated = customer.copyWith(
      totalPurchases: customer.totalPurchases + 1,
      totalSpent: customer.totalSpent + preCreditNet,
      updatedAt: now,
    );

    // 3. Evaluate bonus rule.
    double bonusGranted = 0.0;
    final rule = await _ruleService.load();
    if (rule.enabled &&
        rule.thresholdAmount > 0 &&
        rule.bonusAmount > 0 &&
        rule.windowDays > 0) {
      final windowStart = now.subtract(Duration(days: rule.windowDays));
      final allSales = await _saleRepo.getAllSales();
      double spendInWindow = 0.0;
      for (final s in allSales) {
        if (s.customerId != customer.id) continue;
        if (s.createdAt.isBefore(windowStart)) continue;
        spendInWindow += s.total + s.creditApplied;
      }
      // Include current sale if it is not yet persisted in the repo.
      if (!allSales.any((s) => s.id == sale.id)) {
        spendInWindow += preCreditNet;
      }

      final entries = await _creditRepo.entriesForCustomer(customer.id);
      double bonusAmountInWindow = 0.0;
      for (final e in entries) {
        if (e.type != CustomerCreditEntryType.bonus) continue;
        if (e.createdAt.isBefore(windowStart)) continue;
        bonusAmountInWindow += e.amount;
      }
      // Each ledger entry can already represent multiple thresholds (a single
      // qualifying sale grants `eligibleCount * bonusAmount` consolidated into
      // one row), so derive thresholds satisfied from the granted amount, not
      // from the entry count. `round()` tolerates legacy entries created at a
      // slightly different bonus amount.
      final thresholdsAlreadyGranted =
          (bonusAmountInWindow / rule.bonusAmount).round();

      final eligibleCount =
          (spendInWindow / rule.thresholdAmount).floor() -
              thresholdsAlreadyGranted;
      if (eligibleCount > 0) {
        bonusGranted = eligibleCount * rule.bonusAmount;
        await _creditRepo.insertEntry(
          CustomerCreditEntry(
            id: 'bonus-${sale.id}',
            customerId: customer.id,
            type: CustomerCreditEntryType.bonus,
            amount: bonusGranted,
            saleId: sale.id,
            reason:
                'Spent ${rule.thresholdAmount.toStringAsFixed(2)} within ${rule.windowDays}d',
            createdAt: now,
          ),
        );
        updated = updated.copyWith(
          creditBalance: updated.creditBalance + bonusGranted,
          totalBonusEarned: updated.totalBonusEarned + bonusGranted,
          updatedAt: now,
        );
      }
    }

    await _customerRepo.updateCustomer(updated);

    return BonusApplicationResult(
      updatedCustomer: updated,
      bonusEarned: bonusGranted,
      totalSpentAfter: updated.totalSpent,
      creditBalanceAfter: updated.creditBalance,
    );
  }

  /// Record a manual credit adjustment (admin panel / customer profile).
  /// Positive [amount] credits the customer; negative debits.
  Future<Customer?> recordManualAdjustment({
    required String customerId,
    required double amount,
    String? reason,
  }) async {
    if (amount == 0) return null;
    final customer = await _customerRepo.getCustomerById(customerId);
    if (customer == null) return null;
    final now = DateTime.now();
    await _creditRepo.insertEntry(
      CustomerCreditEntry(
        id: 'adj-${now.millisecondsSinceEpoch}',
        customerId: customerId,
        type: CustomerCreditEntryType.manualAdjustment,
        amount: amount,
        reason: reason,
        createdAt: now,
      ),
    );
    final updated = customer.copyWith(
      creditBalance: customer.creditBalance + amount,
      totalBonusEarned:
          amount > 0 ? customer.totalBonusEarned + amount : customer.totalBonusEarned,
      totalCreditRedeemed: amount < 0
          ? customer.totalCreditRedeemed + amount.abs()
          : customer.totalCreditRedeemed,
      updatedAt: now,
    );
    await _customerRepo.updateCustomer(updated);
    return updated;
  }
}
