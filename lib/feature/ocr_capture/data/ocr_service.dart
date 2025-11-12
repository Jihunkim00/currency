// lib/feature/ocr_capture/data/ocr_service.dart
import 'dart:ui' show Rect;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/entities.dart'; // OcrBox(Must be: const OcrBox(this.bbox, this.text))

/// 금액 후보(내부용)
class OcrAmountCandidate {
  final Rect bbox;
  final String text;
  final double value;
  final String? currencyCode;

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

        final merged = _mergeElementsAsNumberAware(line.elements);

        boxes.add(
          OcrBox(
            Rect.fromLTWH(
              b.left.toDouble(),
              b.top.toDouble(),
              b.width.toDouble(),
              b.height.toDouble(),
            ),
            merged,
          ),
        );
      }
    }
    return boxes;
  }

  /// 신규: 금액 후보 추출 (블록→행(row) 단위 병합 + KRW 근접도/형식 필터)
  Future<List<OcrAmountCandidate>> recognizeAmountCandidates(InputImage image) async {
    final result = await _recognizer.processImage(image);
    final out = <OcrAmountCandidate>[];

    for (final block in result.blocks) {
      final elements = block.lines.expand((l) => l.elements).toList();
      if (elements.isEmpty) continue;

      final rows = _groupRows(elements);

      for (var i = 0; i < rows.length; i++) {
        final currText = _rowText(rows[i]);
        if (_isNoiseRow(currText)) continue;

        // prev가 콤마로 끝나고 curr가 3자리로 시작하면 결합 텍스트로 파싱
        var textToUse = currText;
        if (i > 0) {
          final prevText = _rowText(rows[i - 1]);
          final joined = _maybeJoinRows(prevText, currText);
          if (joined != prevText) textToUse = joined;
        }

        // === 통화/값 추출 ===
        final hasWonMark = textToUse.contains('원') || textToUse.contains('₩');

        double? value;
        String? code;

        // 1) KRW 표식이 있으면 근접도 기반으로 우선 추출
        if (hasWonMark) {
          value = _extractKRWAmountWithProximity(textToUse);
          if (value != null) code = 'KRW';
        }

        // 2) 폴백: 일반 규칙 (콤마 포함 후보 우선)
        value ??= _extractFirstNumber(textToUse);
        if (value == null) continue;

        // 3) KRW 규칙 적용: 소액/소수점 컷
        if (code == 'KRW' || hasWonMark) {
          if (value < 1000) continue;          // 1, 19, 273 같은 노이즈 제거
          value = value.roundToDouble();        // KRW는 소수점 제거
        }

        // 4) 통화코드 보강
        if (code == null) {
          final symbol = _detectCurrencySymbol(textToUse);
          final codeFromSymbol = _symbolToCode[symbol];
          final codeFromAlpha = _detectAlphaCurrencyCode(textToUse);
          code = codeFromSymbol ?? codeFromAlpha;
        }

        final bbox = block.boundingBox;
        out.add(
          OcrAmountCandidate(
            bbox: Rect.fromLTWH(
              bbox.left.toDouble(),
              bbox.top.toDouble(),
              bbox.width.toDouble(),
              bbox.height.toDouble(),
            ),
            text: textToUse,
            value: value,
            currencyCode: code,
          ),
        );
      }
    }

    // 통화코드 있는 후보 우선 → bbox top 순
    out.sort((a, b) {
      final ap = a.currencyCode != null ? 0 : 1;
      final bp = b.currencyCode != null ? 0 : 1;
      if (ap != bp) return ap - bp;
      return a.bbox.top.compareTo(b.bbox.top);
    });

    return out;
  }

  /// ----- 통화/정규화/파싱 유틸 -----

  String? _detectCurrencySymbol(String s) {
    for (final sym in _symbolToCode.keys) {
      if (sym.isEmpty) continue;
      if (s.contains(sym)) return sym;
    }
    return null;
  }

  String? _detectAlphaCurrencyCode(String s) {
    final reg = RegExp(r'\b([A-Z]{3})\b');
    final m = reg.firstMatch(s);
    if (m == null) return null;
    final code = m.group(1)!;
    return _knownCodes.contains(code) ? code : null;
  }

  /// 숫자-공백-3자리 패턴을 콤마로 정규화 + 콤마 좌우 공백 제거
  String _normalizeCommaSpaces(String s) {
    s = s.replaceAll(RegExp(r'(?<=\d)\s+(?=\d{3}\b)'), ',');   // "19 000" → "19,000"
    var out = s.replaceAll(RegExp(r'\s*,\s*'), ',');          // "19, 000" → "19,000"
    out = out.replaceAllMapped(RegExp(r'(\d),(?=\d{3}\b)'), (m) => '${m.group(1)},');
    return out;
  }

  /// 콤마가 있으면 그 후보만 우선(단일 숫자 후순위)
  double? _extractFirstNumber(String s) {
    s = s.replaceAll(RegExp(r'(?<=\d)\s+(?=\d{3}\b)'), ',');
    final normalizedForScan = s.replaceAll(RegExp(r'\s*,\s*'), ',');
    final reg = RegExp(r'(?<!\d)(?:\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)(?!\d)');
    final matches = reg.allMatches(normalizedForScan).toList();
    if (matches.isEmpty) return null;

    final commaCandidates = matches.where((m) => m.group(0)!.contains(',')).toList();
    final pool = commaCandidates.isNotEmpty ? commaCandidates : matches;

    double? bestValue;
    int bestLen = -1;

    for (final m in pool) {
      final raw = m.group(0)!;
      final numeric = raw.replaceAll(',', '');
      final v = double.tryParse(numeric);
      if (v == null) continue;

      final len = numeric.length;
      final better = (len > bestLen) || (len == bestLen && (bestValue == null || v > bestValue));
      if (better) {
        bestLen = len;
        bestValue = v;
      }
    }
    return bestValue;
  }

  /// KRW 근접도 기반 추출: '원/₩'와 가까운 숫자만, (콤마 있거나) 4자리 이상만 허용
  double? _extractKRWAmountWithProximity(String s) {
    final src = _normalizeCommaSpaces(s);

    final numRe = RegExp(r'(?<!\d)(?:\d{1,3}(?:,\d{3})+|\d+)(?!\d)');
    final matches = numRe.allMatches(src).toList();
    if (matches.isEmpty) return null;

    final wonIdx = <int>[];
    for (var i = 0; i < src.length; i++) {
      final ch = src[i];
      if (ch == '원' || ch == '₩') wonIdx.add(i);
    }
    if (wonIdx.isEmpty) return null;

    final candidates = <_ScoredKRW>[];
    for (final m in matches) {
      final raw = m.group(0)!;                 // "17,273" 또는 "17273" 또는 "19"
      final numeric = raw.replaceAll(',', '');
      final hasComma = raw.contains(',');
      final digitLen = numeric.length;

      // 형식 필터: 콤마가 없으면 4자리 이상(>=1000)만 허용
      if (!hasComma && digitLen < 4) continue;

      final numEnd = m.end;
      int bestDist = 1 << 30;
      for (final w in wonIdx) {
        final dist = (w - numEnd).abs();
        if (dist < bestDist) bestDist = dist;
      }
      // 허용 거리: 숫자 끝에서 '원/₩'까지 최대 4글자
      if (bestDist > 4) continue;

      final v = double.tryParse(numeric);
      if (v == null) continue;

      candidates.add(_ScoredKRW(
        value: v,
        raw: raw,
        hasComma: hasComma,
        digitLen: digitLen,
        dist: bestDist,
      ));
    }

    if (candidates.isEmpty) return null;

    // 정렬: 근접(작은 dist) > 콤마 포함 > 자릿수 > 값
    candidates.sort((a, b) {
      final c = a.dist.compareTo(b.dist);
      if (c != 0) return c;
      if (a.hasComma != b.hasComma) return (a.hasComma ? 0 : 1) - (b.hasComma ? 0 : 1);
      final d = b.digitLen.compareTo(a.digitLen);
      if (d != 0) return d;
      return b.value.compareTo(a.value);
    });

    return candidates.first.value;
  }

  /// 부가 노이즈 라인(시간, 카드번호 등) 컷
  bool _isNoiseRow(String s) {
    if (RegExp(r'\d{1,2}:\d{2}(:\d{2})?').hasMatch(s)) return true;         // 18:25:07
    if (RegExp(r'\d{3,4}-\d{3,4}-[\d*]{3,}').hasMatch(s)) return true;      // 4890-1604-****-393*
    if (s.contains('거래일시') || s.contains('카드번호') || s.contains('승인')) return true;
    return false;
  }

  /// ----- 행(row) 병합 유틸 -----

  List<List<TextElement>> _groupRows(List<TextElement> elements) {
    if (elements.isEmpty) return [];
    elements.sort((a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy));

    final rows = <List<TextElement>>[];
    final avgH = elements.map((e) => e.boundingBox.height).reduce((a, b) => a + b) / elements.length;

    for (final el in elements) {
      final cy = el.boundingBox.center.dy;
      final thresh = avgH * 0.6; // 같은 행으로 볼 y 허용치

      bool placed = false;
      for (final row in rows) {
        final rcy = row.first.boundingBox.center.dy;
        if ((cy - rcy).abs() <= thresh) {
          row.add(el);
          placed = true;
          break;
        }
      }
      if (!placed) rows.add([el]);
    }

    for (final row in rows) {
      row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
    }
    return rows;
  }

  String _rowText(List<TextElement> row) => _mergeElementsAsNumberAware(row);

  String _maybeJoinRows(String prev, String next) {
    final p = _normalizeCommaSpaces(prev);
    final n = _normalizeCommaSpaces(next);
    if (p.trim().endsWith(',') && RegExp(r'^\s*\d{3}\b').hasMatch(n)) {
      return '$p$n';
    }
    return prev;
  }

  /// 요소 기반 숫자-구분자-숫자 붙여쓰기
  String _mergeElementsAsNumberAware(List<TextElement> elements) {
    if (elements.isEmpty) return '';
    elements.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

    final avgH = elements.map((e) => e.boundingBox.height).fold<double>(0, (s, h) => s + h) / elements.length;

    bool isNumFrag(String s) {
      final t = s.replaceAll(RegExp(r'[\s\u00A0\u2000-\u200B]'), '');
      return RegExp(r'^[0-9.,\-]+$').hasMatch(t);
    }

    final buf = StringBuffer();
    Rect? prevBox;
    String? prevText;

    for (final el in elements) {
      final t = el.text;
      final box = el.boundingBox;

      if (buf.isEmpty) {
        buf.write(t);
      } else {
        final gap = box.left - (prevBox!.right);

        // 콤마/점/하이픈 다음에 숫자가 오는 경우, 간극 허용을 넉넉히
        bool punctDigitGlue = false;
        if (prevText != null &&
            RegExp(r'[,.\-]$').hasMatch(prevText!) &&
            RegExp(r'^\d+$').hasMatch(t)) {
          punctDigitGlue = gap < avgH * 0.65;
        }

        final shouldGlue =
            (gap < avgH * 0.35 && isNumFrag(prevText!) && isNumFrag(t)) || punctDigitGlue;

        if (shouldGlue) {
          buf.write(t); // 공백 없이 결합
        } else {
          buf.write(' ');
          buf.write(t);
        }
      }

      prevBox = box;
      prevText = t;
    }
    return buf.toString();
  }

  void dispose() => _recognizer.close();
}

/// 통화 심볼 → 코드 간단 매핑
const Map<String, String> _symbolToCode = {
  r'$': 'USD',
  '₩': 'KRW',
  '원': 'KRW',
  '€': 'EUR',
  '¥': 'JPY',
  '£': 'GBP',
  'A\$': 'AUD',
  'C\$': 'CAD',
};

/// 허용 통화 코드 화이트리스트
const Set<String> _knownCodes = {
  'USD','KRW','EUR','JPY','CNY','GBP','AUD','CAD','NZD','HKD','SGD','TWD',
};

/// 내부: KRW 후보 스코어
class _ScoredKRW {
  final double value;
  final String raw;
  final bool hasComma;
  final int digitLen;
  final int dist; // 숫자 끝 ↔ '원/₩' 거리 (문자 수)
  _ScoredKRW({
    required this.value,
    required this.raw,
    required this.hasComma,
    required this.digitLen,
    required this.dist,
  });
}
