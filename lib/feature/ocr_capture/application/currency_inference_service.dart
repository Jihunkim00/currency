import 'dart:ui';

import '../../settings/domain/entities.dart';
import '../data/location_service.dart';

class CurrencyInferenceService {
  CurrencyInferenceService(this._locationService);

  final ILocationService _locationService;

  String? _cachedLocationCurrency;
  DateTime? _lastLocationAttempt;

  Future<String> inferFallbackCurrency(AppSettings settings, Locale locale) async {
    final fromSettings = settings.displayCurrency;
    final fromLocale = _localeToCurrency(locale.languageCode, locale.countryCode);

    final now = DateTime.now();
    final canAttemptLocation = _lastLocationAttempt == null ||
        now.difference(_lastLocationAttempt!) > const Duration(minutes: 5);

    if (canAttemptLocation && _cachedLocationCurrency == null) {
      _lastLocationAttempt = now;
      _cachedLocationCurrency = await _locationService.getCurrencyByLocation();
    }

    return _cachedLocationCurrency ?? fromLocale ?? fromSettings;
  }

  String? _localeToCurrency(String languageCode, String? countryCode) {
    final cc = (countryCode ?? '').toUpperCase();
    const byCountry = {
      'US': 'USD',
      'KR': 'KRW',
      'JP': 'JPY',
      'GB': 'GBP',
      'AU': 'AUD',
      'NZ': 'NZD',
      'CA': 'CAD',
      'DE': 'EUR',
      'FR': 'EUR',
      'IT': 'EUR',
      'ES': 'EUR',
      'CN': 'CNY',
      'HK': 'HKD',
      'SG': 'SGD',
    };
    if (byCountry.containsKey(cc)) return byCountry[cc];

    const byLang = {
      'ko': 'KRW',
      'ja': 'JPY',
      'en': 'USD',
      'de': 'EUR',
      'fr': 'EUR',
      'it': 'EUR',
      'es': 'EUR',
      'zh': 'CNY',
    };
    return byLang[languageCode.toLowerCase()];
  }
}