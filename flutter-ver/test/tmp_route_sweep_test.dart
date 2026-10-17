import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futechi/app/router.dart';
import 'package:futechi/app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const routes = <(String, Object?)>[
    (FutechiRoutes.dashboard, null),
    (FutechiRoutes.history, null),
    (FutechiRoutes.healthAlerts, null),
    (FutechiRoutes.consultation, 'a24'),
    (FutechiRoutes.feedingAnalysis, 'a24'),
    (FutechiRoutes.report, 'a24'),
    (FutechiRoutes.feeding, null),
    (FutechiRoutes.treatment, null),
    (FutechiRoutes.treatmentDetail, 'vaksin-nd'),
    (FutechiRoutes.notifications, null),
    (FutechiRoutes.profile, null),
    ('${FutechiRoutes.techi}/alert-a24', null),
  ];
  for (final size in const [Size(360, 740), Size(390, 844), Size(820, 1180)]) {
    for (final (name, arg) in routes) {
      testWidgets('$name @ ${size.width.toInt()}', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) {
          final loc = RegExp(r'lib/[\w/]+\.dart:\d+').allMatches(d.toString()).map((m) => m.group(0)).toSet().join(',');
          errors.add('${d.exceptionAsString().split('\n').first} @ $loc');
        };
        await tester.pumpWidget(MaterialApp(
          theme: FutechiTheme.build(),
          onGenerateRoute: (s) => buildRoute(RouteSettings(name: name, arguments: arg)),
        ));
        await tester.pump(const Duration(milliseconds: 500));
        // Scroll through lists so lazily built children are laid out.
        for (final s in find.byType(Scrollable).evaluate().toList()) {
          final st = (s as StatefulElement).state as ScrollableState;
          if (st.position.maxScrollExtent > 0) {
            st.position.jumpTo(st.position.maxScrollExtent / 2);
            await tester.pump();
            st.position.jumpTo(st.position.maxScrollExtent);
            await tester.pump();
          }
        }
        FlutterError.onError = old;
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 15));
        if (errors.isNotEmpty) {
          // ignore: avoid_print
          print('ERRORS $name @ ${size.width}: ${errors.toSet().join(' | ')}');
        }
      });
    }
  }
}
