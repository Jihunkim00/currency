import 'package:flutter/foundation.dart';
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
  void add(MoneyCandidate m){
    debugPrint('[Calc] add: ${m.amount} ${m.sourceCurrency} at ${m.box.bbox}');
    state = state.add(m);
  debugPrint('[Calc] selected count: ${state.selected.length}');}
  void clear(){
    debugPrint('[Calc] clear (before=${state.selected.length})');
    state = state.clear(); }
}

// calc_notifier.dart (파일 하단에 추가)

class SumStep {
  final MoneyCandidate item;   // 원본 통화/금액/박스
  final double converted;      // 표시통화로 환산된 값
  final double runningTotal;   // 여기까지 누적합
  const SumStep({
    required this.item,
    required this.converted,
    required this.runningTotal,
  });
}

extension CalcBreakdown on CalcState {
  /// rates/표시통화 기준으로 항목 하나씩 환산하면서 누적합 단계 리스트 생성
  List<SumStep> buildSteps(RatesTable rates, String displayCcy) {
    final out = <SumStep>[];
    var acc = 0.0;
    for (final m in selected) {
      final v = rates.convert(m.sourceCurrency, displayCcy, m.amount) ?? 0.0;
      acc += v;
      out.add(SumStep(item: m, converted: v, runningTotal: acc));
    }
    return out;
  }
}
