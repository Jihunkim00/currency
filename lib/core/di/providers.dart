// lib/core/di/providers.dart
import 'package:hooks_riverpod/hooks_riverpod.dart';

// ▼ 캡처 상태/노티파이어
import '../../feature/ocr_capture/application/capture_notifier.dart';

// ▼ (이미 있으실) 다른 provider 들…
import '../../feature/settings/data/settings_local_data_source.dart';
import '../../feature/settings/application/settings_notifier.dart';
import '../../feature/settings/domain/entities.dart';
import '../../feature/rates/data/rates_api.dart';
import '../../feature/rates/data/rates_repository_impl.dart';
import '../../feature/rates/application/rates_notifier.dart';
import '../../feature/rates/domain/entities.dart';
import '../../feature/calc/application/calc_notifier.dart';
import '../../feature/ocr_capture/data/location_service.dart'; // ILocationService, LocationService

// Settings
final settingsProvider =
StateNotifierProvider<SettingsNotifier, AsyncValue<AppSettings>>((ref) {
  return SettingsNotifier(SettingsLocalDataSource());
});

// Rates
final ratesProvider =
StateNotifierProvider<RatesNotifier, AsyncValue<RatesTable>>((ref) {
  final repo = RatesRepositoryImpl(RatesApi());
  return RatesNotifier(repo);
});

// LocationService (DI)
final locationServiceProvider = Provider<ILocationService>((ref) {
  return LocationService();
});

// ✅ Capture (GPS 통화 fallback 쓰려면 LocationService 주입)
final captureProvider =
StateNotifierProvider<CaptureNotifier, CaptureState>((ref) {
  final loc = ref.read(locationServiceProvider);
  return CaptureNotifier(loc);
});

// Calc
final calcProvider =
StateNotifierProvider<CalcNotifier, CalcState>((ref) {
  return CalcNotifier();
});
