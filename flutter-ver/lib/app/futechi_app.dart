import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'router.dart';
import 'theme.dart';

/// Port of react-js/src/routes/__root.tsx (root component + shell).
///
/// Wires onGenerateRoute and keeps the shell chrome
/// (header/bottom nav/FAB) aware of the current route. Device-local stores
/// are loaded lazily by their consumers (app shell, screens).
class FutechiApp extends StatefulWidget {
  const FutechiApp({super.key});

  @override
  State<FutechiApp> createState() => _FutechiAppState();
}

class _FutechiAppState extends State<FutechiApp> {
  String _currentRoute = FutechiRoutes.dashboard;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Futechi — Smart Poultry Farm',
      debugShowCheckedModeBanner: false,
      theme: FutechiTheme.build(),
      initialRoute: FutechiRoutes.dashboard,
      onGenerateRoute: buildRoute,
      builder: (context, child) {
        final settings = ModalRoute.of(context)?.settings;
        final name = settings?.name;
        if (name != null && name.isNotEmpty && child != null) {
          _currentRoute = name;
        }
        return AppShell(currentRoute: _currentRoute, child: child ?? const SizedBox.shrink());
      },
    );
  }
}
