import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

abstract class ILocationService {
  Future<String?> getCurrencyByLocation();
}
class LocationService implements ILocationService {
  String? _cachedCurrency;      // ✅ 첫 성공값 캐시
  bool _attemptedOnce = false;  // ✅ 앱 구동 중 1회만 시도
  @override
  Future<String?> getCurrencyByLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // await Geolocator.openLocationSettings();
      return null;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings(); // 다시는 안 뜸 → 설정 유도
      return null;
    }
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission(); // ⬅️ 여기서 프롬프트
      if (perm == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return null;
      }
      if (perm == LocationPermission.denied) return null;
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

    _cachedCurrency = _countryToCurrency[iso] ?? 'USD'; // ✅ 캐시에 저장

    return _cachedCurrency;
  }
}

// 간단 매핑 테이블 (필요 시 확장)
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
