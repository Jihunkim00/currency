class AppSettings {
  final String dollarDefault;          // "$" -> USD/AUD/NZD/CAD
  final String displayCurrency;        // 결과(표시) 통화 (예: KRW)
  final bool autoInferSourceCurrency;  // 원문 통화 자동 추정
  final bool calibrationModeEnabled; // 임시 디버그 보정 UI on/off
  final double overlayOffsetX;
  final double overlayOffsetY;
  final double overlayScaleX;
  final double overlayScaleY;
  final double labelOffsetX;
  final double labelOffsetY;
  final double labelScale;
  final double portraitPreviewScaleX;
  final double portraitPreviewScaleY;

  const AppSettings({
    this.dollarDefault = 'USD',
    this.displayCurrency = 'KRW',
    this.autoInferSourceCurrency = true,
    this.calibrationModeEnabled = false,
    this.overlayOffsetX = 0,
    this.overlayOffsetY = 0,
    this.overlayScaleX = 1.0,
    this.overlayScaleY = 1.0,
    this.labelOffsetX = 0,
    this.labelOffsetY = 0,
    this.labelScale = 1.0,
    this.portraitPreviewScaleX = 1.0,
    this.portraitPreviewScaleY = 1.0,
  });

  AppSettings copyWith({
    String? dollarDefault,
    String? displayCurrency,
    bool? autoInferSourceCurrency,
    bool? calibrationModeEnabled,
    double? overlayOffsetX,
    double? overlayOffsetY,
    double? overlayScaleX,
    double? overlayScaleY,
    double? labelOffsetX,
    double? labelOffsetY,
    double? labelScale,
    double? portraitPreviewScaleX,
    double? portraitPreviewScaleY,
  }) {
    return AppSettings(
      dollarDefault: dollarDefault ?? this.dollarDefault,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      autoInferSourceCurrency:
      autoInferSourceCurrency ?? this.autoInferSourceCurrency,
      calibrationModeEnabled:
      calibrationModeEnabled ?? this.calibrationModeEnabled,
      overlayOffsetX: overlayOffsetX ?? this.overlayOffsetX,
      overlayOffsetY: overlayOffsetY ?? this.overlayOffsetY,
      overlayScaleX: overlayScaleX ?? this.overlayScaleX,
      overlayScaleY: overlayScaleY ?? this.overlayScaleY,
      labelOffsetX: labelOffsetX ?? this.labelOffsetX,
      labelOffsetY: labelOffsetY ?? this.labelOffsetY,
      labelScale: labelScale ?? this.labelScale,
      portraitPreviewScaleX:
      portraitPreviewScaleX ?? this.portraitPreviewScaleX,
      portraitPreviewScaleY:
      portraitPreviewScaleY ?? this.portraitPreviewScaleY,
    );
  }

  Map<String, dynamic> toJson() => {
    'dollarDefault': dollarDefault,
    'displayCurrency': displayCurrency,
    'autoInferSourceCurrency': autoInferSourceCurrency,
    'calibrationModeEnabled': calibrationModeEnabled,
    'overlayOffsetX': overlayOffsetX,
    'overlayOffsetY': overlayOffsetY,
    'overlayScaleX': overlayScaleX,
    'overlayScaleY': overlayScaleY,
    'labelOffsetX': labelOffsetX,
    'labelOffsetY': labelOffsetY,
    'labelScale': labelScale,
    'portraitPreviewScaleX': portraitPreviewScaleX,
    'portraitPreviewScaleY': portraitPreviewScaleY,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    dollarDefault: (j['dollarDefault'] ?? 'USD') as String,
    displayCurrency: (j['displayCurrency'] ?? 'KRW') as String,
    autoInferSourceCurrency: (j['autoInferSourceCurrency'] ?? true) as bool,
    calibrationModeEnabled: (j['calibrationModeEnabled'] ?? false) as bool,
    overlayOffsetX: (j['overlayOffsetX'] ?? 0).toDouble(),
    overlayOffsetY: (j['overlayOffsetY'] ?? 0).toDouble(),
    overlayScaleX: (j['overlayScaleX'] ?? 1.0).toDouble(),
    overlayScaleY: (j['overlayScaleY'] ?? 1.0).toDouble(),
    labelOffsetX: (j['labelOffsetX'] ?? 0).toDouble(),
    labelOffsetY: (j['labelOffsetY'] ?? 0).toDouble(),
    labelScale: (j['labelScale'] ?? 1.0).toDouble(),
    portraitPreviewScaleX: (j['portraitPreviewScaleX'] ?? 1.0).toDouble(),
    portraitPreviewScaleY: (j['portraitPreviewScaleY'] ?? 1.0).toDouble(),
  );
}