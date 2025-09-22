import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../domain/entities.dart';
import '../domain/rates_repository.dart';

class RatesNotifier extends StateNotifier<AsyncValue<RatesTable>> {
  final RatesRepository repo;

  RatesNotifier(this.repo) : super(const AsyncValue.loading()) {
    _load(); // 생성 시 1회 로드
  }

  // 내부 초기 로드: 에러를 state로 올려서 UI가 처리 가능하게
  Future<void> _load() async {
    debugPrint('[Rates] _load() start');
    // 첫 로드: 로딩만 표시
    state = const AsyncValue.loading();
    final next = await AsyncValue.guard<RatesTable>(() => repo.ensure());
    if (!mounted) return;
    state = next;
  }

  /// 외부에서 호출하는 새로고침
  /// - 기존 데이터를 유지한 채 로딩 상태로 전환(UX 좋음)
  /// - repo.refresh() 실패 시, 이전 데이터로 복구 + error 표면화
  Future<void> refresh() async {
    debugPrint('[Rates] refresh() called');
    // 이전 데이터 유지한 로딩 상태로 전환
    state = const AsyncLoading<RatesTable>().copyWithPrevious(state);

    final next = await AsyncValue.guard<RatesTable>(() => repo.refresh());

    if (!mounted) return;

    // 실패 시 next는 AsyncError. 이전 데이터가 있으면 유지되며, 에러 상태도 함께 보유
    state = next.when(
      data: (t) => AsyncValue.data(t),
      error: (e, st) {
        // 실패해도 캐시가 repo에서 반환되었다면 위 data 분기로 들어옴.
        // 여기로 왔다는 건 캐시도 없었거나 진짜 실패라는 뜻.
        debugPrint('Rates refresh error: $e');
        return AsyncValue.error(e, st);
      },
      loading: () => state, // guard 내부적으로 loading이 나올 일은 거의 없음
    );
  }

  /// 편의 함수: 특정 통화의 USD 기준 환율 반환 (없으면 null)
  double? rateOf(String code) {
    final value = state.asData?.value;
    return value?.baseUsdRates[code];
  }

// 기존 USD 전용 함수는 혼란 유발 → 교체 권장
  double? convert(String fromCurrency, String toCurrency, double amount) {
    final table = state.asData?.value;
    if (table == null) return null;
    return table.convert(fromCurrency, toCurrency, amount);
  }




}


