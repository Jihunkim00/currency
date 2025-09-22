// lib/feature/rates/data/rates_api.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rates_api_firestore.dart';

/// 기존 레포/프로바이더가 기대하는 타입명 유지: RatesApi
class RatesApi {
  final RatesApiFirestore _fs;

  RatesApi({
    FirebaseFirestore? db,
    String collectionPath = 'fx_core',
    String docId = 'USD',
  }) : _fs = RatesApiFirestore(
    db: db,
    collectionPath: collectionPath,
    docId: docId,
  );

  Future<Map<String, double>> fetchUsdBase() => _fs.fetchUsdBase();
}
