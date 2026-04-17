import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../feature/calc/application/calc_notifier.dart';
import '../../feature/ocr_capture/application/capture_notifier.dart';
import '../../feature/ocr_capture/application/currency_inference_service.dart';
import '../../feature/ocr_capture/data/location_service.dart';
import '../../feature/rates/application/rates_notifier.dart';
import '../../feature/rates/data/rates_api.dart';
import '../../feature/rates/data/rates_repository_impl.dart';
import '../../feature/rates/domain/entities.dart';
import '../../feature/settings/application/settings_notifier.dart';
import '../../feature/settings/data/settings_local_data_source.dart';
import '../../feature/settings/domain/entities.dart';

final settingsProvider =
StateNotifierProvider<SettingsNotifier, AsyncValue<AppSettings>>((ref) {
  return SettingsNotifier(SettingsLocalDataSource());
});

final ratesProvider =
StateNotifierProvider<RatesNotifier, AsyncValue<RatesTable>>((ref) {
  final repo = RatesRepositoryImpl(RatesApi());
  return RatesNotifier(repo);
});

final locationServiceProvider = Provider<ILocationService>((ref) {
  return LocationService();
});

final currencyInferenceProvider = Provider<CurrencyInferenceService>((ref) {
  return CurrencyInferenceService(ref.read(locationServiceProvider));
});

final captureProvider =
StateNotifierProvider<CaptureNotifier, CaptureState>((ref) {
  return CaptureNotifier(
    inferenceService: ref.read(currencyInferenceProvider),
  );
});

final calcProvider = StateNotifierProvider<CalcNotifier, CalcState>((ref) {
  return CalcNotifier();
});