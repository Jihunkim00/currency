import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities.dart';

const _kKey = 'app_settings_v1';

class SettingsLocalDataSource {
  /// 전체 로드
  Future<AppSettings> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kKey);
    if (raw == null) return const AppSettings();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(map);
    } catch (_) {
      // 깨진 저장본 대비: 안전하게 기본값 반환
      return const AppSettings();
    }
  }

  /// 전체 저장
  Future<void> save(AppSettings s) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(s.toJson());
    await sp.setString(_kKey, raw);
  }

  // ---------------------------
  // ✅ 부분 업데이트 헬퍼 (편의 메서드)
  // ---------------------------

  /// '$' 기본 해석 통화만 갱신 (USD/AUD/NZD/CAD 등)
  Future<void> saveDollarDefault(String code) async {
    final current = await load();
    final next = current.copyWith(dollarDefault: code);
    await save(next);
  }

  /// 표시 통화(합계 표시용)만 갱신 (KRW/EUR/JPY/…)
  Future<void> saveDisplayCurrency(String code) async {
    final current = await load();
    final next = current.copyWith(displayCurrency: code);
    await save(next);
  }

  /// 자동 통화 추론 on/off만 갱신
  Future<void> saveAutoInferSourceCurrency(bool value) async {
    final current = await load();
    final next = current.copyWith(autoInferSourceCurrency: value);
    await save(next);
  }
}
