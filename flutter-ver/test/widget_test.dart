import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:futechi/app/futechi_app.dart';

void main() {
  testWidgets('App renders dashboard smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FutechiApp());
    await tester.pump();

    expect(find.text('Dashboard'), findsWidgets);
  });
}
