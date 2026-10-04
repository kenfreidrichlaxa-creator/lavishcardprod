/// Single source of truth for LVP (Prima Service Value) loading calculations.
///
/// Tiered bonus rules:
///   • below ₱2,500          → REJECTED (nothing credited)
///   • ₱2,500 – ₱3,999.99     → fixed ₱500 bonus
///   • ₱4,000 and above       → 25% bonus
///
/// Uses integer-centavo math internally so results are decimal-safe (no
/// floating-point drift on money values).
class LvpCalculator {
  LvpCalculator._();

  /// Minimum accepted loading amount (in pesos).
  static const double minimumLoad = 2500.0;

  /// Fixed bonus for the ₱2,500–₱3,999 tier (in pesos).
  static const double fixedBonus = 500.0;

  /// Threshold at/above which the 25% bonus applies (in pesos).
  static const double percentThreshold = 4000.0;

  /// Bonus rate for the top tier.
  static const double percentRate = 0.25;

  /// Computes the LVP loading result for a given [amount] (in pesos).
  static LvpLoadResult compute(double amount) {
    // Reject invalid / non-positive amounts.
    if (amount.isNaN || amount.isInfinite || amount <= 0) {
      return const LvpLoadResult(
        loadingAmount: 0,
        bonus: 0,
        credited: 0,
        accepted: false,
        reason: 'Enter a valid amount.',
      );
    }

    // Work in integer centavos to avoid floating-point rounding errors.
    final cents = _toCents(amount);
    const minCents = 250000; // ₱2,500.00
    const fixedBonusCents = 50000; // ₱500.00
    const thresholdCents = 400000; // ₱4,000.00

    if (cents < minCents) {
      return LvpLoadResult(
        loadingAmount: _fromCents(cents),
        bonus: 0,
        credited: 0,
        accepted: false,
        reason: 'Minimum loading is ₱2,500.00.',
      );
    }

    int bonusCents;
    if (cents >= thresholdCents) {
      // 25% bonus, rounded to the nearest centavo.
      bonusCents = ((cents * 25) / 100).round();
    } else {
      bonusCents = fixedBonusCents;
    }

    final creditedCents = cents + bonusCents;
    return LvpLoadResult(
      loadingAmount: _fromCents(cents),
      bonus: _fromCents(bonusCents),
      credited: _fromCents(creditedCents),
      accepted: true,
    );
  }

  static int _toCents(double pesos) => (pesos * 100).round();
  static double _fromCents(int cents) => cents / 100.0;
}

/// The result of an LVP loading calculation.
class LvpLoadResult {
  const LvpLoadResult({
    required this.loadingAmount,
    required this.bonus,
    required this.credited,
    required this.accepted,
    this.reason,
  });

  /// The entered loading amount (pesos).
  final double loadingAmount;

  /// Bonus that will be added (pesos). 0 when rejected.
  final double bonus;

  /// Total LVP credited to the wallet (loadingAmount + bonus). 0 when rejected.
  final double credited;

  /// Whether the loading is allowed.
  final bool accepted;

  /// Why the loading was rejected (null when accepted).
  final String? reason;
}
