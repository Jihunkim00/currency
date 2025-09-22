abstract class RatesSource {
  /// USD 기준 환율 맵 (예: {KRW: 1380.1, JPY: 156.3, ...})
  Future<Map<String, double>> fetchUsdBase();
}
