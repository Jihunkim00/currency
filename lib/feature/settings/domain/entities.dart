class AppSettings {
  final String dollarDefault;          // "$" -> USD/AUD/NZD/CAD
  final String displayCurrency;        // 결과(표시) 통화 (예: KRW)
  final bool autoInferSourceCurrency;  // 원문 통화 자동 추정

  const AppSettings({
    this.dollarDefault = 'USD',
    this.displayCurrency = 'KRW',
    this.autoInferSourceCurrency = true,
  });

  AppSettings copyWith({
    String? dollarDefault,
    String? displayCurrency,
    bool? autoInferSourceCurrency,
  }) {
    return AppSettings(
      dollarDefault: dollarDefault ?? this.dollarDefault,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      autoInferSourceCurrency:
      autoInferSourceCurrency ?? this.autoInferSourceCurrency,
    );
  }

  Map<String, dynamic> toJson() => {
    'dollarDefault': dollarDefault,
    'displayCurrency': displayCurrency,
    'autoInferSourceCurrency': autoInferSourceCurrency,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    dollarDefault: (j['dollarDefault'] ?? 'USD') as String,
    displayCurrency: (j['displayCurrency'] ?? 'KRW') as String,
    autoInferSourceCurrency: (j['autoInferSourceCurrency'] ?? true) as bool,
  );
}
