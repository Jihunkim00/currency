// lib/feature/rates/data/rates_repository_impl.dart
import 'package:flutter/foundation.dart';
import '../domain/entities.dart';
import '../domain/rates_repository.dart';
import 'rates_api.dart'; // 기존 HTTP API (남겨두어도 됨)

class RatesRepositoryImpl implements RatesRepository {
  final RatesApi? api;                              // 기존
  final Future<Map<String,double>> Function()? _fetcher; // 새로 추가
  RatesTable? _cache;

  RatesRepositoryImpl(this.api) : _fetcher = null;

  /// 함수 주입으로 어떤 소스든 사용 가능 (Firestore, 로컬파일 등)
  RatesRepositoryImpl.fromFetcher({required Future<Map<String,double>> Function() fetcher})
      : api = null, _fetcher = fetcher;

  @override
  Future<RatesTable> ensure() async {
    if (_cache != null) {
      debugPrint('[RatesRepo] ensure: using cache');
      return _cache!;
    }
    return refresh();
  }

  @override
  Future<RatesTable> refresh() async {
    debugPrint('[RatesRepo] refresh()');
    Map<String,double> map;
    if (_fetcher != null) {
      map = await _fetcher!();
    } else if (api != null) {
      map = await api!.fetchUsdBase();
    } else {
      throw Exception('No rates fetcher configured');
    }
    _cache = RatesTable(
      base: 'USD',
      lastSync: DateTime.now(),
      baseUsdRates: map,
    );
    debugPrint('[RatesRepo] refreshed: ${map.length} codes');
    return _cache!;
  }
}
