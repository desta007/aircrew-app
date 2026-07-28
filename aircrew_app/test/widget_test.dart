import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aircrew_app/main.dart';

void main() {
  testWidgets('Role selector shows both apps', (tester) async {
    await initializeDateFormatting('id_ID');
    await tester.pumpWidget(const AirCrewApp());
    expect(find.text('Aplikasi Mitra Driver'), findsOneWidget);
    expect(find.text('Aplikasi Customer (Crew)'), findsOneWidget);
  });
}
