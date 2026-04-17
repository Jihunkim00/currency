import 'dart:collection';

import '../domain/entities.dart';

class CandidateStabilizer {
  CandidateStabilizer({
    this.windowSize = 6,
    this.minSeenCount = 2,
  });

  final int windowSize;
  final int minSeenCount;

  final Queue<List<MoneyCandidate>> _frames = Queue<List<MoneyCandidate>>();

  List<MoneyCandidate> push(List<MoneyCandidate> frameCandidates) {
    _frames.addLast(frameCandidates);
    while (_frames.length > windowSize) {
      _frames.removeFirst();
    }

    final seen = <String, _SeenCandidate>{};
    for (final frame in _frames) {
      final frameKeys = <String>{};
      for (final candidate in frame) {
        final key = _softKey(candidate);
        if (!frameKeys.add(key)) continue;
        final current = seen[key];
        if (current == null) {
          seen[key] = _SeenCandidate(candidate: candidate, count: 1);
        } else {
          seen[key] = _SeenCandidate(
            candidate: current.candidate.score >= candidate.score
                ? current.candidate
                : candidate,
            count: current.count + 1,
          );
        }
      }
    }

    final stable = seen.values
        .where((item) => item.count >= minSeenCount)
        .map((item) => item.candidate.copyWith(score: item.candidate.score + (item.count * 0.05)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return stable;
  }

  void clear() {
    _frames.clear();
  }

  String _softKey(MoneyCandidate c) {
    final amountBucket = c.amount.toStringAsFixed(2);
    final xBucket = (c.box.bbox.center.dx / 30).round();
    final yBucket = (c.box.bbox.center.dy / 30).round();
    return '${c.sourceCurrency}|$amountBucket|$xBucket|$yBucket';
  }
}

class _SeenCandidate {
  final MoneyCandidate candidate;
  final int count;

  const _SeenCandidate({required this.candidate, required this.count});
}