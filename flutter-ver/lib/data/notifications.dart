/// Port of useNotifications from react-js/src/components/futechi-extra-pages.tsx
library;

import 'package:flutter/foundation.dart';

import 'case_state.dart';
import 'health_case.dart';
import 'treatments.dart';

enum NotifKind { health, treatment }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    required this.urgent,
    required this.targetRoute,
    required this.targetId,
  });

  final String id;
  final NotifKind kind;
  final String title;
  final String body;
  final String time;
  final bool urgent;
  /// 'consultation' opens /history/consultation/:id, 'treatment' opens
  /// /treatment/:id in the router.
  final NotifTarget targetRoute;
  final String targetId;
}

enum NotifTarget { consultation, treatment }

class NotificationsModel extends ChangeNotifier {
  NotificationsModel._() {
    CaseStateStore.instance.addListener(_refresh);
    TreatmentStore.instance.addListener(_refresh);
  }
  static final NotificationsModel instance = NotificationsModel._();

  List<AppNotification> _list = [];
  int _unread = 0;

  List<AppNotification> get list => _list;
  int get unread => _unread;

  void _refresh() {
    final caseStore = CaseStateStore.instance;
    final treatmentStore = TreatmentStore.instance;
    if (!caseStore.loaded || !treatmentStore.loaded) return;

    final notifications = <AppNotification>[];
    for (final c in sortedHealthCases) {
      if (caseStore.statusFor(c) == CaseStatus.healthy) continue;
      notifications.add(
        AppNotification(
          id: 'case-${c.id}',
          kind: NotifKind.health,
          title: 'Ayam terdeteksi sakit · ${c.cage}',
          body:
              'Hasil analisis video feeding ${c.session == FeedingSession.morning ? "Pagi" : "Sore"} pada ${c.chickenId}. Segera lakukan pemeriksaan gejala.',
          time: '${c.date}, ${c.time}',
          urgent: c.level == CaseLevel.kritis,
          targetRoute: NotifTarget.consultation,
          targetId: c.id,
        ),
      );
    }
    for (final t in treatments) {
      final reminder = treatmentStore.reminderFor(t.id);
      if (reminder.enabled == false || treatmentStore.isDone(t.id)) continue;
      final snoozed = reminder.snoozedUntil;
      notifications.add(
        AppNotification(
          id: 'treat-${t.id}${snoozed != null ? '-${snoozed.toIso8601String()}' : ''}',
          kind: NotifKind.treatment,
          title: 'Pengingat: ${t.name}',
          body: snoozed != null
              ? 'Reminder ditunda hingga ${_formatDateTime(snoozed)}.'
              : '${t.target} · ${t.product}',
          time: t.schedule,
          urgent: t.status == TreatmentStatus.mendesak,
          targetRoute: NotifTarget.treatment,
          targetId: t.id,
        ),
      );
    }
    _list = notifications;
    _unread = notifications.where((n) => !treatmentStore.isRead(n.id)).length;
    notifyListeners();
  }

  Future<void> markRead(Iterable<String> ids) =>
      TreatmentStore.instance.markRead(ids);

  bool isRead(String id) => TreatmentStore.instance.isRead(id);

  static String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hh.$mm';
  }
}
