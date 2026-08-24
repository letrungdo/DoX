class AssetSummary {
  const AssetSummary({
    required this.totalSavings,
    required this.totalInvestments,
    required this.totalGold,
    required this.monthlyInterest,
    required this.totalProfitLoss,
    required this.averageAnnualReturn,
  });

  final double totalSavings;
  final double totalInvestments;
  final double totalGold;
  final double monthlyInterest;
  final double totalProfitLoss;
  final double averageAnnualReturn;

  double get totalAssets => totalSavings + totalInvestments + totalGold;
}
