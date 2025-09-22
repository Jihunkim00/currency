import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'rates_source.dart'; // ★ 추가

class RatesApiFirestore implements RatesSource { // ★ 인터페이스 구현
  final FirebaseFirestore _db;
  final String collectionPath;
  final String docId;

  RatesApiFirestore({
    FirebaseFirestore? db,
    this.collectionPath = 'fx_core',
    this.docId = 'USD',
  }) : _db = db ?? FirebaseFirestore.instance;

  @override
  Future<Map<String, double>> fetchUsdBase() async {
    final snap = await _db.collection(collectionPath).doc(docId).get();
    if (!snap.exists) throw Exception('Firestore: $collectionPath/$docId not found');

    final data = snap.data();
    if (data == null) throw Exception('Firestore: empty document');

    final ratesField = data['rates'];
    if (ratesField is Map) {
      final Map<String, double> out = {};
      ratesField.forEach((k, v) {
        final code = '$k'.toUpperCase();
        final num? n = v is num ? v : num.tryParse('$v');
        if (n != null && _isCurrencyCode(code)) out[code] = n.toDouble();
      });
      if (out.isEmpty) throw Exception('Firestore: empty rates map');
      debugPrint('[RatesApiFS] parsed from rates{}: ${out.length} codes');
      return out;
    }

    final Map<String, double> out = {};
    for (final entry in data.entries) {
      final key = entry.key;
      if (!_isCurrencyCode(key)) continue;
      final val = entry.value;
      final num? n = val is num ? val : num.tryParse('$val');
      if (n != null) out[key] = n.toDouble();
    }
    if (out.isEmpty) {
      debugPrint('[RatesApiFS] unexpected shape: $data');
      throw Exception('Firestore: no currency fields');
    }
    debugPrint('[RatesApiFS] parsed from flat fields: ${out.length} codes');
    return out;
  }

  bool _isCurrencyCode(String s) => s.length == 3 && RegExp(r'^[A-Z]{3}$').hasMatch(s);
}
