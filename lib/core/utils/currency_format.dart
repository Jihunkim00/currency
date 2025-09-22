import 'package:intl/intl.dart';
String formatDisplay(double v, String ccy){
  final f = NumberFormat.currency(name: ccy, symbol: '');
  return '$ccy ${f.format(v)}';
}
