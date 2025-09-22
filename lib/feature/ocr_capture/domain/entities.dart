// lib/feature/ocr_capture/domain/entities.dart
import 'dart:ui';

class OcrBox {
  final Rect bbox;
  final String text;
  const OcrBox(this.bbox, this.text);
}

class MoneyCandidate {
  final OcrBox box;
  final String sourceCurrency; // USD/EUR/JPY/KRW ...
  final double amount;
  const MoneyCandidate({
    required this.box,
    required this.sourceCurrency,
    required this.amount,
  });
}
