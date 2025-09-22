import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../domain/entities.dart';
import '../data/settings_local_data_source.dart';
import '../../../core/constants.dart'; // 경로는 프로젝트 구조에 맞게

class SettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  final SettingsLocalDataSource ds;
  SettingsNotifier(this.ds) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ds.load();
      state = AsyncValue.data(s);
    } catch (_) {
      // 깨진 저장값/이전 포맷일 때도 앱이 죽지 않도록 기본값으로 복구
      state = const AsyncValue.data(AppSettings());
    }
  }

  Future<void> update(AppSettings s) async {
    state = AsyncValue.data(s);
    await ds.save(s);
  }

  Future<void> setDollarDefault(String code) async {
    if (!kDollarDefaultOptions.contains(code)) return; // 가드
    final cur = state.value ?? const AppSettings();
    final next = cur.copyWith(dollarDefault: code);
    state = AsyncValue.data(next);
    await ds.saveDollarDefault(code); // ← _local → ds 로 수정
  }

  Future<void> setDisplayCurrency(String code) async {
    if (!kSupportedCurrencies.contains(code)) return; // 가드
    final cur = state.value ?? const AppSettings();
    final next = cur.copyWith(displayCurrency: code);
    state = AsyncValue.data(next);
    await ds.saveDisplayCurrency(code); // ← _local → ds 로 수정
  }

  // (선택) 자동 추론 토글 저장도 추가
  Future<void> setAutoInferSourceCurrency(bool value) async {
    final cur = state.value ?? const AppSettings();
    final next = cur.copyWith(autoInferSourceCurrency: value);
    state = AsyncValue.data(next);
    await ds.saveAutoInferSourceCurrency(value);
  }
}
