import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

/// Port of react-js/src/routes/__root.tsx (root component + shell).
///
/// Wires onGenerateRoute; each route is wrapped in the shell chrome
/// (header/bottom nav/FAB) by [buildRoute]. Device-local stores
/// are loaded lazily by their consumers (app shell, screens).
class FutechiApp extends StatelessWidget {
  const FutechiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Futechi — Smart Poultry Farm',
      debugShowCheckedModeBanner: false,
      theme: FutechiTheme.build(),
      initialRoute: FutechiRoutes.dashboard,
      onGenerateRoute: buildRoute,
    );
  }
}
