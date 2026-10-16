import 'package:flutter/material.dart';

import '../data/health_case.dart';
import '../data/notifications.dart';
import '../screens/consultation_page.dart';
import '../screens/dashboard_page.dart';
import '../screens/feeding_page.dart';
import '../screens/health_alerts_page.dart';
import '../screens/history_page.dart';
import '../screens/notifications_page.dart';
import '../screens/profile_page.dart';
import '../screens/treatment_detail_page.dart';
import '../screens/treatment_page.dart';
import '../screens/techi/techi_chat_screen.dart';
import 'app_shell.dart';

/// Flutter port of the react-js TanStack route tree.
///
/// Route names mirror the react routes; parameters are passed via
/// `RouteSettings.arguments` (a String id) or `arguments` map.
class FutechiRoutes {
  static const dashboard = '/';
  static const history = '/history';
  static const healthAlerts = '/history/health-alerts';
  static const consultation = '/history/consultation';
  static const feedingAnalysis = '/history/feeding-analysis';
  static const report = '/history/report';
  static const feeding = '/feeding';
  static const treatment = '/treatment';
  static const treatmentDetail = '/treatment/detail';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const techi = '/techi';
}

Route<Object?> buildRoute(RouteSettings settings) {
  final name = settings.name ?? FutechiRoutes.dashboard;
  final arg = settings.arguments;
  final id = arg is String ? arg : (arg is Map ? arg['id'] as String? : null);

  Widget page;
  switch (name) {
    case FutechiRoutes.history:
      page = const HistoryPage();
      break;
    case FutechiRoutes.healthAlerts:
      page = const HealthAlertsPage();
      break;
    case FutechiRoutes.consultation:
      page = ConsultationPage(alertId: id ?? defaultHealthCase.id);
      break;
    case FutechiRoutes.feedingAnalysis:
      page = ConsultationPage(alertId: id ?? defaultHealthCase.id);
      break;
    case FutechiRoutes.report:
      page = const ConsultationPage(alertId: 'a24');
      break;
    case FutechiRoutes.feeding:
      page = const FeedingPage();
      break;
    case FutechiRoutes.treatment:
      page = const TreatmentPage();
      break;
    case FutechiRoutes.treatmentDetail:
      page = TreatmentDetailPage(treatmentId: id ?? 'vaksin-nd');
      break;
    case FutechiRoutes.notifications:
      page = const NotificationsPage();
      break;
    case FutechiRoutes.profile:
      page = const ProfilePage();
      break;
    case FutechiRoutes.techi:
      page = const TechiChatScreen(threadId: 'current');
      break;
    case FutechiRoutes.dashboard:
    default:
      // /techi/:threadId falls through as a prefixed route of /techi.
      if (name.startsWith('${FutechiRoutes.techi}/')) {
        page = TechiChatScreen(
          threadId: name.substring(FutechiRoutes.techi.length + 1),
        );
      } else {
        page = const DashboardPage();
      }
  }
  return MaterialPageRoute<Object?>(
    settings: settings,
    builder: (_) => AppShell(currentRoute: name, child: page),
  );
}

/// Navigates to a named route with a case id (consultation) or treatment id.
void pushRoute(
  BuildContext context,
  String route, {
  String? id,
  Map<String, String>? params,
}) {
  Navigator.of(context).pushNamed(route,
      arguments: id ?? params?['id'] ?? params?['alertId'] ?? params?['treatmentId']);
}

/// Shared navigation helper for notification targets.
void openNotification(BuildContext context, AppNotification n) {
  final route = n.targetRoute == NotifTarget.consultation
      ? FutechiRoutes.consultation
      : FutechiRoutes.treatmentDetail;
  pushRoute(context, route, id: n.targetId);
}
