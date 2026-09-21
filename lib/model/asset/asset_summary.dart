/// One asset class rolled up: what went in, what it is worth now, how many
/// records it holds.
///
/// Savings put their principal in [cost] and principal + accrued interest in
/// [value], so the interest earned reads as profit exactly the way an
/// investment's gain does and the three classes can be compared side by side.
class AssetClassStat {
  const AssetClassStat({
    required this.cost,
    required this.value,
    required this.count,
  });

  const AssetClassStat.empty() : cost = 0, value = 0, count = 0;

  /// What was paid in, in VND.
  final double cost;

  /// What it is worth today, in VND.
  final double value;

  /// How many records make it up.
  final int count;

  double get profitLoss => value - cost;

  double get profitLossPercent => cost > 0 ? (profitLoss / cost) * 100 : 0;
}

/// A single holding singled out for its return, so the page can name the one
/// carrying the portfolio and the one dragging on it.
class AssetPerformer {
  const AssetPerformer({
    required this.name,
    required this.profitLoss,
    required this.profitLossPercent,
  });

  final String name;
  final double profitLoss;
  final double profitLossPercent;
}

class AssetSummary {
  const AssetSummary({
    required this.savings,
    required this.investments,
    required this.gold,
    required this.monthlyInterest,
    required this.monthlyProfit,
    required this.averageAnnualReturn,
    required this.maturedSavingsCount,
    this.nextMaturityDate,
    this.nextMaturityBank,
    this.best,
    this.worst,
  });

  final AssetClassStat savings;
  final AssetClassStat investments;
  final AssetClassStat gold;

  /// Interest the live deposits pay over the coming month, in VND.
  final double monthlyInterest;

  /// What the whole portfolio earns in an average month, in VND: the deposits'
  /// interest plus every investment's and gold holding's gain spread over how
  /// long it has been held.
  final double monthlyProfit;

  /// The portfolio's return restated as a yearly rate in %, weighted by what
  /// each holding cost.
  final double averageAnnualReturn;

  /// Deposits whose term has already ended — they have stopped earning and are
  /// waiting to be rolled over.
  final int maturedSavingsCount;

  /// The first term still to end, and the bank holding it.
  final DateTime? nextMaturityDate;
  final String? nextMaturityBank;

  final AssetPerformer? best;
  final AssetPerformer? worst;

  double get totalSavings => savings.value;

  double get totalInvestments => investments.value;

  double get totalGold => gold.value;

  double get totalAssets => savings.value + investments.value + gold.value;

  /// What the whole portfolio cost: deposit principal plus what was paid for
  /// every investment and gold holding.
  double get totalCost => savings.cost + investments.cost + gold.cost;

  double get totalProfitLoss => totalAssets - totalCost;

  double get totalProfitLossPercent =>
      totalCost > 0 ? (totalProfitLoss / totalCost) * 100 : 0;

  /// What [averageAnnualReturn] works out to in VND over a year, on what is
  /// held today.
  double get estimatedYearlyProfit => totalAssets * (averageAnnualReturn / 100);

  /// The share of the portfolio a class holds, in %.
  double shareOf(AssetClassStat stat) {
    final total = totalAssets;

    return total > 0 ? (stat.value / total) * 100 : 0;
  }
}
