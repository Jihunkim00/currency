import 'dart:ui';

class OcrBox {
  final Rect bbox;
  final String text;
  const OcrBox(this.bbox, this.text);
}

class MoneyCandidate {
  final OcrBox box;
  final String sourceCurrency;
  final double amount;
  final String normalizedText;
  final double score;
  final bool inferredCurrency;

  const MoneyCandidate({
    required this.box,
    required this.sourceCurrency,
    required this.amount,
    this.normalizedText = '',
    this.score = 0,
    this.inferredCurrency = false,
  });

  String get dedupeKey {
    final rounded = amount.toStringAsFixed(2);
    final left = box.bbox.left.round();
    final top = box.bbox.top.round();
    return '$sourceCurrency|$rounded|$left|$top';
  }

  MoneyCandidate copyWith({
    OcrBox? box,
    String? sourceCurrency,
    double? amount,
    String? normalizedText,
    double? score,
    bool? inferredCurrency,
  }) {
    return MoneyCandidate(
      box: box ?? this.box,
      sourceCurrency: sourceCurrency ?? this.sourceCurrency,
      amount: amount ?? this.amount,
      normalizedText: normalizedText ?? this.normalizedText,
      score: score ?? this.score,
      inferredCurrency: inferredCurrency ?? this.inferredCurrency,
    );
  }
}