// lib/feature/ocr_capture/data/ocr_service.dart
import 'dart:ui' show Rect;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/entities.dart'; // OcrBox(Must be: const OcrBox(this.bbox, this.text))

/// 금액 후보(내부용). 외부에 노출할 필요가 없으면 이 파일 안에 둡니다.
class OcrAmountCandidate {
  final Rect bbox;
  final String text;
  final double value;
  final String? currencyCode; // 예: "USD", "KRW" (없으면 null)

  const OcrAmountCandidate({
    required this.bbox,
    required this.text,
    required this.value,
    this.currencyCode,
  });

  @override
  String toString() =>
      'OcrAmountCandidate(value: $value, currencyCode: $currencyCode, text: "$text")';
}

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer();

  /// 기존: OCR 결과를 OcrBox들로 그대로 반환 (호환성 유지)
  Future<List<OcrBox>> recognizeFromInputImage(InputImage image) async {
    final result = await _recognizer.processImage(image);
    final boxes = <OcrBox>[];

    for (final block in result.blocks) {
      for (final line in block.lines) {
        final b = line.boundingBox;
        if (b == null) continue;

        // ✅ OcrBox는 포지셔널 2개 (bbox, text)
        boxes.add(
          OcrBox(
            Rect.fromLTWH(
              b.left.toDouble(),
              b.top.toDouble(),
              b.width.toDouble(),
              b.height.toDouble(),
            ),
            line.text,
          ),
        );
      }
    }
    return boxes;
  }

  /// 신규: 금액 후보 추출
  /// - 통화 기호/코드가 붙은 라인을 우선 반환
  /// - 없으면 숫자만 있는 라인도 후보에 포함 (currencyCode = null)
  Future<List<OcrAmountCandidate>> recognizeAmountCandidates(
      InputImage image) async {
    final result = await _recognizer.processImage(image);
    final candidates = <OcrAmountCandidate>[];

    for (final block in result.blocks) {
      for (final line in block.lines) {
        final bbox = line.boundingBox;
        if (bbox == null) continue;

        final text = line.text;
        final value = _extractFirstNumber(text);
        if (value == null) continue;

        final symbol = _detectCurrencySymbol(text);
        final codeFromSymbol = _symbolToCode[symbol];
        final codeFromAlpha = _detectAlphaCurrencyCode(text);

        final code = codeFromSymbol ?? codeFromAlpha;

        candidates.add(
          OcrAmountCandidate(
            bbox: Rect.fromLTWH(
              bbox.left.toDouble(),
              bbox.top.toDouble(),
              bbox.width.toDouble(),
              bbox.height.toDouble(),
            ),
            text: text,
            value: value,
            currencyCode: code, // 없으면 null
          ),
        );
      }
    }

    // 정렬: 통화코드 있는 후보 우선, 그다음 숫자만
    candidates.sort((a, b) {
      final ap = a.currencyCode != null ? 0 : 1;
      final bp = b.currencyCode != null ? 0 : 1;
      if (ap != bp) return ap - bp;
      // 동일 우선순위면 bbox 상단(y) 기준으로 위에 있는 것 먼저
      return a.bbox.top.compareTo(b.bbox.top);
    });

    return candidates;
  }

  /// 통화 기호 감지: $, ₩, €, ¥ 등
  String? _detectCurrencySymbol(String s) {
    for (final sym in _symbolToCode.keys) {
      if (s.contains(sym)) return sym;
    }
    return null;
  }

  /// 알파벳 통화코드 감지: USD, KRW, EUR 등 (대문자 3글자 토큰)
  String? _detectAlphaCurrencyCode(String s) {
    final reg = RegExp(r'\b([A-Z]{3})\b');
    final m = reg.firstMatch(s);
    if (m == null) return null;
    final code = m.group(1)!;
    return _knownCodes.contains(code) ? code : null;
  }

  /// 문자열에서 첫 번째 수치 추출 (콤마/공백 제거, 소수점 유지)
  double? _extractFirstNumber(String s) {
    // 예) "₩ 12,345.67", "USD 1,234", "1 234,56" 등 폭넓게 허용
    final reg = RegExp(
      r'[-+]?\d{1,3}([,\s]\d{3})*(\.\d+)?|[-+]?\d+([,]\d+)?',
    );
    final m = reg.firstMatch(s);
    if (m == null) return null;
    final raw = m.group(0)!;

    // 유럽식 "1 234,56"을 단순 정규화: 공백/콤마 제거 후 소수점만 유지
    // (필요하면 로케일별 세분화 가능)
    final normalized = raw.replaceAll(RegExp(r'[\s,]'), '');
    return double.tryParse(normalized);
  }

  void dispose() {
    _recognizer.close();
  }
}

/// 통화 심볼 → 코드 간단 매핑 (필요 시 확장)
const Map<String, String> _symbolToCode = {
  r'$': 'USD',
  '₩': 'KRW',
  '€': 'EUR',
  '¥': 'JPY',
  '£': 'GBP',
  'A\$': 'AUD',
  'C\$': 'CAD',
};

/// 허용 통화 코드 화이트리스트
const Set<String> _knownCodes = {
  'USD',
  'KRW',
  'EUR',
  'JPY',
  'CNY',
  'GBP',
  'AUD',
  'CAD',
  'NZD',
  'HKD',
  'SGD',
  'TWD',
};
