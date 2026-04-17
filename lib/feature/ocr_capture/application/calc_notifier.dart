import 'dart:ui';

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
    final byKey = <String, MoneyCandidate>{};
    for (final c in input) {
      final key = '${c.sourceCurrency}|${c.amount.toStringAsFixed(2)}|'
          '${(c.box.bbox.center.dx / 20).round()}|${(c.box.bbox.center.dy / 20).round()}';
      final existing = byKey[key];
      if (existing == null || c.score > existing.score) {
        byKey[key] = c;
      }
    }
    return byKey.values.toList()..sort((a, b) => b.score.compareTo(a.score));
  }
}