import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:Ratelens/feature/ocr_capture/application/candidate_stabilizer.dart';
import 'package:Ratelens/feature/ocr_capture/domain/entities.dart';
import 'package:Ratelens/feature/ocr_capture/domain/money_text_parser.dart';

void main() {
  const box = OcrBox(Rect.fromLTWH(0, 0, 100, 20), '');
  final parser = MoneyTextParser();

  List<MoneyCandidate> parse(String text, {String fallback = 'USD'}) {
    return parser.parseLine(
      box: OcrBox(box.bbox, text),
      dollarDefault: 'USD',
      fallbackCurrency: fallback,
      autoInfer: true,
    );
  }

  test(r'parses $12.99', () {
    final r = parse(r'$12.99');
    expect(r.first.sourceCurrency, 'USD');
    expect(r.first.amount, closeTo(12.99, 0.001));
  });

  test('parses USD 12.99', () {
    final r = parse('USD 12.99');
    expect(r.first.sourceCurrency, 'USD');
    expect(r.first.amount, closeTo(12.99, 0.001));
  });

  test('parses 12.99 USD', () {
    final r = parse('12.99 USD');
    expect(r.first.sourceCurrency, 'USD');
    expect(r.first.amount, closeTo(12.99, 0.001));
  });

  test('parses ¥1,280', () {
    final r = parse('¥1,280');
    expect(r.first.sourceCurrency, 'JPY');
    expect(r.first.amount, closeTo(1280, 0.001));
  });

  test('parses EUR 1.234,56', () {
    final r = parse('EUR 1.234,56');
    expect(r.first.sourceCurrency, 'EUR');
    expect(r.first.amount, closeTo(1234.56, 0.001));
  });

  test('parses 1 234,50 €', () {
    final r = parse('1 234,50 €');
    expect(r.first.sourceCurrency, 'EUR');
    expect(r.first.amount, closeTo(1234.50, 0.001));
  });

  test('parses KRW 12,000', () {
    final r = parse('KRW 12,000');
    expect(r.first.sourceCurrency, 'KRW');
    expect(r.first.amount, closeTo(12000, 0.001));
  });

  test('parses 12,000 KRW', () {
    final r = parse('12,000 KRW');
    expect(r.first.sourceCurrency, 'KRW');
    expect(r.first.amount, closeTo(12000, 0.001));
  });

  test('ambiguous dollar uses default currency setting', () {
    final result = parser.parseLine(
      box: const OcrBox(Rect.fromLTWH(0, 0, 100, 20), r'$8.99'),
      dollarDefault: 'AUD',
      fallbackCurrency: 'AUD',
      autoInfer: true,
    );
    expect(result.first.sourceCurrency, 'AUD');
  });

  test('filters false positives', () {
    expect(parse('2026-04-10'), isEmpty);
    expect(parse('12:30'), isEmpty);
    expect(parse('15%'), isEmpty);
    expect(parse('order #123456'), isEmpty);
  });

  test('stabilizer surfaces repeated frame detections', () {
    final stabilizer = CandidateStabilizer(windowSize: 4, minSeenCount: 2);
    final c = MoneyCandidate(
      box: const OcrBox(Rect.fromLTWH(10, 10, 30, 10), 'USD 12.99'),
      sourceCurrency: 'USD',
      amount: 12.99,
    );

    final first = stabilizer.push([c]);
    expect(first, isEmpty);

    final second = stabilizer.push([c]);
    expect(second.length, 1);
    expect(second.first.amount, closeTo(12.99, 0.001));
  });
}