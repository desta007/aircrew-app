import 'package:intl/intl.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

String rp(num v) => _rp.format(v);

String rpShort(num v) {
  if (v >= 1000000) {
    final m = v / 1000000;
    return 'Rp ${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)} jt';
  }
  if (v >= 1000) return 'Rp ${(v / 1000).toStringAsFixed(0)} rb';
  return rp(v);
}

final _date = DateFormat('d MMM yyyy', 'id_ID');
final _dateTime = DateFormat('d MMM yyyy • HH:mm', 'id_ID');
final _time = DateFormat('HH:mm', 'id_ID');

String fDate(DateTime d) => _date.format(d);
String fDateTime(DateTime d) => _dateTime.format(d);
String fTime(DateTime d) => _time.format(d);
