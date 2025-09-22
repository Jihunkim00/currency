import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../ocr_capture/domain/entities.dart';
import '../../rates/domain/entities.dart';

class CalcState {
  final List<MoneyCandidate> selected; // 누적 선택
  const CalcState({this.selected = const []});
  double sumInDisplay(RatesTable rates, String displayCcy){
    double total = 0;
    for(final m in selected){
      final v = rates.convert(m.sourceCurrency, displayCcy, m.amount);
      if(v!=null) total += v;
    }
    return total;
  }
  CalcState add(MoneyCandidate m) => CalcState(selected: [...selected, m]);
  CalcState clear() => const CalcState(selected: []);
}

class CalcNotifier extends StateNotifier<CalcState> {
  CalcNotifier(): super(const CalcState());
  void add(MoneyCandidate m){ state = state.add(m); }
  void clear(){ state = state.clear(); }
}
