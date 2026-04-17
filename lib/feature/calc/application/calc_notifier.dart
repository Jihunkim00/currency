import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../ocr_capture/domain/entities.dart';
import '../../rates/domain/entities.dart';

class CalcState {
  final List<MoneyCandidate> selected;

  const CalcState({this.selected = const []});

  double sumInDisplay(RatesTable rates, String displayCcy) {
    double total = 0;
    for (final m in selected) {
      final v = rates.convert(m.sourceCurrency, displayCcy, m.amount);
      if (v != null) total += v;
    }
    return total;
  }

  CalcState add(MoneyCandidate m) => CalcState(selected: [...selected, m]);

  CalcState removeAt(int index) {
    if (index < 0 || index >= selected.length) return this;
    final next = [...selected]..removeAt(index);
    return CalcState(selected: next);
  }

  CalcState updateAmount(int index, double newAmount) {
    if (index < 0 || index >= selected.length || newAmount <= 0) return this;
    final next = [...selected];
    next[index] = next[index].copyWith(amount: newAmount);
    return CalcState(selected: next);
  }

  CalcState clear() => const CalcState(selected: []);
}

class CalcNotifier extends StateNotifier<CalcState> {
  CalcNotifier() : super(const CalcState());

  void add(MoneyCandidate m) => state = state.add(m);

  void removeAt(int index) => state = state.removeAt(index);

  void updateAmount(int index, double newAmount) => state = state.updateAmount(index, newAmount);

  void clear() => state = state.clear();
}