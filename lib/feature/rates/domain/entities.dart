class RatesTable {
  final String base;               // "USD" 같은 기준 통화
  final DateTime lastSync;
  final Map<String,double> baseUsdRates;

  const RatesTable({
    required this.base,
    required this.lastSync,
    required this.baseUsdRates,
  });

  double? convert(String from, String to, double amount) {
    // 변환 로직 그대로
    final fromRate = baseUsdRates[from];
    final toRate = baseUsdRates[to];
    if (fromRate == null || toRate == null) return null;
    return amount / fromRate * toRate;
  }
}
