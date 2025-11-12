// lib/feature/ocr_capture/application/capture_notifier.dart
import 'dart:ui';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../domain/entities.dart';
import '../data/location_service.dart' show ILocationService;

// 1순위: 통화코드/기호 + 금액
final moneyRegex = RegExp(
  r'((USD|AUD|NZD|CAD|EUR|JPY|KRW|GBP|CNY|HKD|SGD)|[€£¥₩$￥￦])\s*([0-9]{1,3}(?:[.,\s\u00A0\u202F][0-9]{3})*|[0-9]+)(?:([.,][0-9]{1,2}))?',
  caseSensitive: false,
);

// 2순위: 숫자만 (양옆에 통화기호/코드가 없는 경우만)
final numberOnlyRegex = RegExp(
  r'(?<![A-Z€£¥₩$￥￦])\b([0-9]{1,3}(?:[.,\s\u00A0\u202F][0-9]{3})*|[0-9]+)(?:([.,][0-9]{1,2}))?\b(?!\s*(USD|AUD|NZD|CAD|EUR|JPY|KRW|GBP|CNY|HKD|SGD)|[€£¥₩$￥￦])',
  caseSensitive: false,
);


String? resolveSymbol(String s, String dollarDefault) {
  switch (s) {
    case '₩':
      return 'KRW';
    case '€':
      return 'EUR';
    case '£':
      return 'GBP';
    case '¥':
      return 'JPY'; // 간소화
    case r'$':
      return dollarDefault; // USD/AUD/NZD/CAD 중 기본
  }
  return null;
}

class CaptureState {
  final Size imageSize;
  final List<MoneyCandidate> candidates;
  const CaptureState({required this.imageSize, required this.candidates});

  CaptureState copyWith({
    Size? imageSize,
    List<MoneyCandidate>? candidates,
  }) =>
      CaptureState(
        imageSize: imageSize ?? this.imageSize,
        candidates: candidates ?? this.candidates,
      );
}

class CaptureNotifier extends StateNotifier<CaptureState> {
  final ILocationService _locationService;
  CaptureNotifier(this._locationService)
      : super(const CaptureState(imageSize: Size(0, 0), candidates: []));

  /// [dollarDefault] : '$'를 어떤 통화로 볼지 (예: 'USD')
  /// [autoInfer]     : 통화 미검출 시 숫자만 후보로라도 올릴지
  /// [fallbackCurrency] : 통화 미검출 시 채울 기본 통화(예: GPS로 얻은 'KRW')
  void update(
      Size imageSize,
      List<OcrBox> boxes,
      String dollarDefault,
      bool autoInfer, {
        String? fallbackCurrency,
      }) {
    final cand = <MoneyCandidate>[];

    for (final b in boxes) {
      final text = b.text;

      // ── 1) 통화코드/기호가 붙은 정상 패턴 먼저 시도
      final m = moneyRegex.firstMatch(text);
      if (m != null) {
        final code3 = m.group(2);                // USD 등
        final symOrCode = m.group(1) ?? '';      // USD 또는 기호
        final sym = code3 == null ? symOrCode : null;
        final ccy =
            code3 ?? (sym != null ? resolveSymbol(sym, dollarDefault) : null);

        final amount = _parseAmount(m.group(3), m.group(4));
        if (ccy != null && amount != null && amount > 0) {
          cand.add(MoneyCandidate(box: b, sourceCurrency: ccy, amount: amount));
          continue; // 이미 통화가 있는 1순위는 우선 채택
        }
      }

      // ── 2) 통화가 없고 autoInfer가 true면, 숫자만 후보로 추출
      if (autoInfer) {
        final n = numberOnlyRegex.firstMatch(text);
        if (n != null) {
          final amount = _parseAmount(n.group(1), n.group(2));
          if (amount != null && amount > 0) {
            // 통화 보완: GPS 등에서 받은 fallbackCurrency > 없으면 dollarDefault
            final ccy = fallbackCurrency ?? dollarDefault;
            // MoneyCandidate가 통화 null을 허용하지 않는다고 가정하고 채워서 추가
            cand.add(MoneyCandidate(box: b, sourceCurrency: ccy, amount: amount));
          }
        }
      }
    }

    state = state.copyWith(imageSize: imageSize, candidates: cand);
  }

  /// intPart: "1,234" / "1 234" / "1234" / "1.234"
  /// decPart: ".56" / ",56" 같은 소수부 (선행 구분자 제거)
  double? _parseAmount(String? intPart, String? decPartRaw) {
    if (intPart == null) return null;
    final decPart = (decPartRaw ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    // 천단위 구분(콤마/공백/점)은 제거, 소수점만 '.'로 구성
    final normalized =
        intPart.replaceAll(RegExp(r'[,\.\s\u00A0\u202F]'), '') + (decPart.isNotEmpty ? '.$decPart' : '');

    return double.tryParse(normalized);
  }

  Future<void> updateWithLocation(
      Size imageSize,
      List<OcrBox> boxes,
      String dollarDefault,
      bool autoInfer,
      ) async {
    final gpsCurrency = await _locationService.getCurrencyByLocation(); // ← 여기서 권한 프롬프트 발생
    update(
      imageSize,
      boxes,
      dollarDefault,
      autoInfer,
      fallbackCurrency: gpsCurrency,
    );
  }


}
