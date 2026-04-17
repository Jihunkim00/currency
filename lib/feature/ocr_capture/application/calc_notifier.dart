import 'dart:ui';
import 'dart:math' as math;
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../settings/domain/entities.dart';
import '../domain/entities.dart';
import '../domain/money_text_parser.dart';
import 'candidate_stabilizer.dart';
import 'currency_inference_service.dart';

class CaptureState {
  final Size imageSize;
  final List<MoneyCandidate> candidates;
  final bool isProcessing;
  final String? warning;

  const CaptureState({
    required this.imageSize,
    required this.candidates,
    this.isProcessing = false,
    this.warning,
  });

  CaptureState copyWith({
    Size? imageSize,
    List<MoneyCandidate>? candidates,
    bool? isProcessing,
    String? warning,
  }) {
    return CaptureState(
      imageSize: imageSize ?? this.imageSize,
      candidates: candidates ?? this.candidates,
      isProcessing: isProcessing ?? this.isProcessing,
      warning: warning,
    );
  }
}

class CaptureNotifier extends StateNotifier<CaptureState> {
  CaptureNotifier({
    required CurrencyInferenceService inferenceService,
    MoneyTextParser? parser,
    CandidateStabilizer? stabilizer,
  })  : _inferenceService = inferenceService,
        _parser = parser ?? MoneyTextParser(),
        _stabilizer = stabilizer ?? CandidateStabilizer(),
        super(const CaptureState(imageSize: Size(0, 0), candidates: []));

  final CurrencyInferenceService _inferenceService;
  final MoneyTextParser _parser;
  final CandidateStabilizer _stabilizer;

  Future<void> update({
    required Size imageSize,
    required List<OcrBox> boxes,
    required AppSettings settings,
    required Locale locale,
  }) async {
    state = state.copyWith(isProcessing: true, imageSize: imageSize);

    try {
      final fallback = settings.autoInferSourceCurrency
          ? await _inferenceService.inferFallbackCurrency(settings, locale)
          : settings.dollarDefault;

      final parsed = <MoneyCandidate>[];
      for (final box in boxes) {
        parsed.addAll(
          _parser.parseLine(
            box: box,
            dollarDefault: settings.dollarDefault,
            fallbackCurrency: fallback,
            autoInfer: settings.autoInferSourceCurrency,
          ),
        );
      }

      final stable = _stabilizer.push(_dedupeSpatial(parsed));

      state = state.copyWith(
        candidates: stable,
        isProcessing: false,
        warning: stable.isEmpty ? 'No stable prices yet. Hold camera steady.' : null,
      );
    } catch (_) {
      state = state.copyWith(
        isProcessing: false,
        warning: 'OCR parsing failed. Try moving closer to price text.',
      );
    }
  }

  void clear() {
    _stabilizer.clear();
    state = state.copyWith(candidates: const [], warning: null);
  }

  List<MoneyCandidate> _dedupeSpatial(List<MoneyCandidate> input) {
    final filtered = input.where(_isMeaningfulCandidate).toList();
    final byKey = <String, MoneyCandidate>{};
    for (final c in filtered) {
      final key = '${c.sourceCurrency}|${c.amount.toStringAsFixed(2)}|'
          '${(c.box.bbox.center.dx / 20).round()}|${(c.box.bbox.center.dy / 20).round()}';
      final existing = byKey[key];
      if (existing == null || c.score > existing.score) {
        byKey[key] = c;
      }
    }

    final merged = _dedupeOverlapping(byKey.values.toList());
    merged.sort((a, b) => _visualRank(b).compareTo(_visualRank(a)));
    return merged.take(7).toList();
  }

  bool _isMeaningfulCandidate(MoneyCandidate c) {
    if (c.amount <= 0) return false;
    if (c.normalizedText.length > 42) return false;
    if (!RegExp(r'[0-9]').hasMatch(c.normalizedText)) return false;

    final area = c.box.bbox.width * c.box.bbox.height;
    if (area < 140) return false;

    final alphaNumCount = RegExp(r'[A-Za-z0-9€£¥￥₩￦$]').allMatches(c.normalizedText).length;
    final garbageCount = RegExp(r'[^A-Za-z0-9\s,\.€£¥￥₩￦$-]').allMatches(c.normalizedText).length;
    if (garbageCount > alphaNumCount) return false;

    if (RegExp(r'\d{9,}').hasMatch(c.normalizedText)) return false;
    return true;
  }

  List<MoneyCandidate> _dedupeOverlapping(List<MoneyCandidate> values) {
    if (values.length <= 1) return values;

    final sorted = [...values]..sort((a, b) => _visualRank(b).compareTo(_visualRank(a)));
    final chosen = <MoneyCandidate>[];

    for (final candidate in sorted) {
      final duplicate = chosen.any((existing) {
        if (existing.sourceCurrency != candidate.sourceCurrency) return false;
        if ((existing.amount - candidate.amount).abs() > 0.009) return false;
        final iou = _iou(existing.box.bbox, candidate.box.bbox);
        final centerDistance = (existing.box.bbox.center - candidate.box.bbox.center).distance;
        return iou >= 0.55 || centerDistance < 18;
      });
      if (!duplicate) {
        chosen.add(candidate);
      }
    }

    return chosen;
  }

  double _visualRank(MoneyCandidate candidate) {
    final area = candidate.box.bbox.width * candidate.box.bbox.height;
    final explicitCurrencyBoost = candidate.inferredCurrency ? 0.0 : 0.20;
    final amountBoost = candidate.amount >= 0.3 && candidate.amount < 100000 ? 0.12 : -0.08;
    final areaBoost = math.min(0.25, math.log(area + 1) / 30);
    return candidate.score + explicitCurrencyBoost + amountBoost + areaBoost;
  }

  double _iou(Rect a, Rect b) {
    final overlap = a.intersect(b);
    if (overlap.isEmpty) return 0;
    final interArea = overlap.width * overlap.height;
    final unionArea = (a.width * a.height) + (b.width * b.height) - interArea;
    if (unionArea <= 0) return 0;
    return interArea / unionArea;
  }
}