import 'dart:math' as math;

import 'entities.dart';

class ParsedMoneyToken {
  final String? currency;
  final String amountToken;
  final bool currencyBefore;
  final bool inferredCurrency;
  final String normalizedText;

  const ParsedMoneyToken({
    required this.currency,
    required this.amountToken,
    required this.currencyBefore,
    required this.inferredCurrency,
    required this.normalizedText,
  });
}

class MoneyTextParser {
  static const _currencyCodes = <String>{
    'USD', 'AUD', 'NZD', 'CAD', 'EUR', 'JPY', 'KRW', 'GBP', 'CNY', 'HKD', 'SGD'
  };

  static const _symbolToCurrency = <String, String>{
    '€': 'EUR',
    '£': 'GBP',
    '¥': 'JPY',
    '￥': 'JPY',
    '₩': 'KRW',
    '￦': 'KRW',
  };

  List<MoneyCandidate> parseLine({
    required OcrBox box,
    required String dollarDefault,
    required String? fallbackCurrency,
    required bool autoInfer,
  }) {
    final raw = _normalizeForTokenizing(box.text);
    if (_isFalsePositive(raw)) return const [];

    final merged = _mergeSplitCurrencyAndAmount(raw);
    final out = <MoneyCandidate>[];

    out.addAll(_extractWithCurrencyBefore(merged, box, dollarDefault));
    out.addAll(_extractWithAmountBefore(merged, box, dollarDefault));
    out.addAll(_extractSymbolOnly(merged, box, dollarDefault));

    if (out.isEmpty && autoInfer) {
      final number = _extractBestNumberToken(merged);
      if (number != null) {
        final amount = parseLocalizedAmount(number);
        final currency = fallbackCurrency ?? dollarDefault;
        if (amount != null && amount > 0) {
          out.add(MoneyCandidate(
            box: box,
            sourceCurrency: currency,
            amount: amount,
            normalizedText: merged,
            score: _baseScore(amount: amount, hasCurrency: false),
            inferredCurrency: true,
          ));
        }
      }
    }

    return _dedupeByValue(out);
  }

  List<MoneyCandidate> _extractWithCurrencyBefore(
      String text,
      OcrBox box,
      String dollarDefault,
      ) {
    final reg = RegExp(
      r'\b(USD|AUD|NZD|CAD|EUR|JPY|KRW|GBP|CNY|HKD|SGD)\b\s*([0-9O][0-9O\s.,]{0,18})',
      caseSensitive: false,
    );

    return reg
        .allMatches(text)
        .map((m) {
      final code = m.group(1)!.toUpperCase();
      final amountToken = m.group(2)!;
      final amount = parseLocalizedAmount(amountToken);
      if (amount == null) return null;
      return MoneyCandidate(
        box: box,
        sourceCurrency: code,
        amount: amount,
        normalizedText: text,
        score: _baseScore(amount: amount, hasCurrency: true) + 0.25,
      );
    })
        .whereType<MoneyCandidate>()
        .toList();
  }

  List<MoneyCandidate> _extractWithAmountBefore(
      String text,
      OcrBox box,
      String dollarDefault,
      ) {
    final reg = RegExp(
      r'([0-9O][0-9O\s.,]{0,18})\s*\b(USD|AUD|NZD|CAD|EUR|JPY|KRW|GBP|CNY|HKD|SGD)\b',
      caseSensitive: false,
    );

    return reg
        .allMatches(text)
        .map((m) {
      final amount = parseLocalizedAmount(m.group(1)!);
      final code = m.group(2)!.toUpperCase();
      if (amount == null) return null;
      return MoneyCandidate(
        box: box,
        sourceCurrency: code,
        amount: amount,
        normalizedText: text,
        score: _baseScore(amount: amount, hasCurrency: true) + 0.25,
      );
    })
        .whereType<MoneyCandidate>()
        .toList();
  }

  List<MoneyCandidate> _extractSymbolOnly(
      String text,
      OcrBox box,
      String dollarDefault,
      ) {
    final reg = RegExp(r'([€£¥￥₩￦$])\s*([0-9O][0-9O\s.,]{0,18})|([0-9O][0-9O\s.,]{0,18})\s*([€£¥￥₩￦$])');

    return reg
        .allMatches(text)
        .map((m) {
      final symbol = m.group(1) ?? m.group(4);
      final numberToken = m.group(2) ?? m.group(3);
      if (symbol == null || numberToken == null) return null;

      final currency = symbol == r'$' ? dollarDefault : _symbolToCurrency[symbol];
      final amount = parseLocalizedAmount(numberToken);
      if (currency == null || amount == null) return null;

      return MoneyCandidate(
        box: box,
        sourceCurrency: currency,
        amount: amount,
        normalizedText: text,
        score: _baseScore(amount: amount, hasCurrency: true) + 0.20,
      );
    })
        .whereType<MoneyCandidate>()
        .toList();
  }

  double? parseLocalizedAmount(String token) {
    var t = token.trim();
    if (t.isEmpty) return null;

    t = t.replaceAll(RegExp(r'(?<=\d)\s+(?=\d{3}(\D|$))'), '');
    t = t.replaceAll('O', '0').replaceAll('o', '0');
    t = t.replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (t.isEmpty) return null;

    // 1.234,56 => decimal comma
    if (t.contains(',') && t.contains('.')) {
      final lastComma = t.lastIndexOf(',');
      final lastDot = t.lastIndexOf('.');
      if (lastComma > lastDot) {
        t = t.replaceAll('.', '');
        t = t.replaceFirst(',', '.');
      } else {
        t = t.replaceAll(',', '');
      }
    } else if (t.contains(',')) {
      final parts = t.split(',');
      if (parts.length > 2) {
        t = parts.join();
      } else if (parts.length == 2 && parts[1].length <= 2) {
        t = '${parts[0]}.${parts[1]}';
      } else {
        t = parts.join();
      }
    } else if (t.contains('.')) {
      final parts = t.split('.');
      if (parts.length > 2) {
        t = parts.join();
      } else if (parts.length == 2 && parts[1].length == 3) {
        t = parts.join();
      }
    }

    final amount = double.tryParse(t);
    if (amount == null || amount <= 0) return null;
    return amount;
  }

  String _normalizeForTokenizing(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'([,\.])\1+'), r'$1')
        .trim();
  }

  String _mergeSplitCurrencyAndAmount(String text) {
    return text
        .replaceAllMapped(
      RegExp(r'\b([A-Z]{3})\s+([0-9])'),
          (m) => '${m.group(1)} ${m.group(2)}',
    )
        .replaceAllMapped(
      RegExp(r'([0-9])\s+\b([A-Z]{3})\b'),
          (m) => '${m.group(1)} ${m.group(2)}',
    );
  }

  bool _isFalsePositive(String text) {
    final upper = text.toUpperCase();
    if (RegExp(r'\b\d{4}-\d{2}-\d{2}\b').hasMatch(upper)) return true;
    if (RegExp(r'\b\d{1,2}:\d{2}(:\d{2})?\b').hasMatch(upper)) return true;
    if (RegExp(r'\b\d{1,3}%\b').hasMatch(upper)) return true;
    if (RegExp(r'\bORDER\s*#?\d{4,}\b').hasMatch(upper)) return true;
    if (RegExp(r'\b(?:\+?\d{1,3}[\s-]?)?(?:\d{2,4}[\s-]){2,}\d{3,4}\b').hasMatch(upper)) return true;
    if (RegExp(r'\bTABLE\s*\d+\b').hasMatch(upper)) return true;
    if (RegExp(r'\bID\s*[:#-]?\s*\d{5,}\b').hasMatch(upper)) return true;
    return false;
  }

  String? _extractBestNumberToken(String text) {
    final matches = RegExp(r'([0-9O][0-9O\s.,]{0,18})').allMatches(text).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.group(0)!.length.compareTo(a.group(0)!.length));
    return matches.first.group(0);
  }

  List<MoneyCandidate> _dedupeByValue(List<MoneyCandidate> values) {
    final bestByKey = <String, MoneyCandidate>{};
    for (final v in values) {
      final key = '${v.sourceCurrency}:${v.amount.toStringAsFixed(2)}';
      final cur = bestByKey[key];
      if (cur == null || v.score > cur.score) bestByKey[key] = v;
    }
    return bestByKey.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  double _baseScore({required double amount, required bool hasCurrency}) {
    var score = hasCurrency ? 0.6 : 0.3;
    if (amount >= 0.3 && amount <= 5000) score += 0.2;
    if (amount > 1000000) score -= 0.2;
    return math.max(0, math.min(1, score));
  }
}