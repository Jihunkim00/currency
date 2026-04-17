import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

abstract class ILocationService {
  Future<String?> getCurrencyByLocation();
}

class LocationService implements ILocationService {
  String? _cachedCurrency;
  bool _attemptedOnce = false;

  @override
  Future<String?> getCurrencyByLocation() async {
    if (_cachedCurrency != null) return _cachedCurrency;
    if (_attemptedOnce) return null;
    _attemptedOnce = true;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm != LocationPermission.always &&
        perm != LocationPermission.whileInUse) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition();
    final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (placemarks.isEmpty) return null;

    final iso = placemarks.first.isoCountryCode?.toUpperCase();
    if (iso == null) return null;

    _cachedCurrency = _countryToCurrency[iso] ?? 'USD';
    return _cachedCurrency;
  }
}

const Map<String, String> _countryToCurrency = {
  'KR': 'KRW',
  'US': 'USD',
  'JP': 'JPY',
  'CN': 'CNY',
  'GB': 'GBP',
  'DE': 'EUR',
  'FR': 'EUR',
  'IT': 'EUR',
  'ES': 'EUR',
  'AU': 'AUD',
  'CA': 'CAD',
  'NZ': 'NZD',
};