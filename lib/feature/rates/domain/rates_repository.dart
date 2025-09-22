import 'entities.dart';

abstract class RatesRepository {
  Future<RatesTable> ensure();   // (e.g., 12h TTL)
  Future<RatesTable> refresh();
}
