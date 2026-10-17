import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../data/notifications.dart';
import '../data/treatments.dart';
import '../widgets/case_card.dart';
import 'treatment_page.dart' show treatmentIcon;

/// Port of NotificationsPage from futechi-extra-pages.tsx.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

enum _Tab { all, health, treatment }

class _NotificationsPageState extends State<NotificationsPage> {
  _Tab _tab = _Tab.all;

  @override
  void initState() {
    super.initState();
    TreatmentStore.instance.load();
    NotificationsModel.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    NotificationsModel.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final model = NotificationsModel.instance;
    final shown = model.list
        .where((n) =>
            _tab == _Tab.all ||
            (_tab == _Tab.health && n.kind == NotifKind.health) ||
            (_tab == _Tab.treatment && n.kind == NotifKind.treatment))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notifikasi',
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text('${model.unread} notifikasi belum dibaca',
                      style: const TextStyle(color: FutechiColors.mutedForeground)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: model.list.isEmpty
                  ? null
                  : () => model.markRead(model.list.map((n) => n.id)),
              icon: const Icon(Icons.done_all_outlined),
              label: const Text('Tandai semua dibaca'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          children: [
            for (final (tab, label) in [
              (_Tab.all, 'Semua'),
              (_Tab.health, 'Kesehatan'),
              (_Tab.treatment, 'Treatment'),
            ])
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _tab == tab
                      ? FutechiColors.primary
                      : FutechiColors.card,
                  foregroundColor: _tab == tab
                      ? FutechiColors.onPrimary
                      : FutechiColors.foreground,
                  side: const BorderSide(color: FutechiColors.border),
                  minimumSize: const Size(0, 36),
                ),
                onPressed: () => setState(() => _tab = tab),
                child: Text(label, style: const TextStyle(fontSize: 13)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (shown.isEmpty)
          const FutechiCard(
            padding: EdgeInsets.all(32),
            child: Text(
              'Tidak ada notifikasi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FutechiColors.mutedForeground),
            ),
          ),
        for (final n in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NotificationTile(notification: n),
          ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final isRead = NotificationsModel.instance.isRead(n.id);
    return Opacity(
      opacity: isRead ? 0.75 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FutechiColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FutechiColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            NotificationsModel.instance.markRead([n.id]);
            openNotification(context, n);
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: FutechiColors.warningSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  n.kind == NotifKind.health
                      ? Icons.videocam_outlined
                      : _treatmentIconFor(n.targetId),
                  color: FutechiColors.warning,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        if (n.urgent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: FutechiColors.dangerSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              n.kind == NotifKind.health ? 'Kritis' : 'Mendesak',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: FutechiColors.danger),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(n.body,
                        style: const TextStyle(
                            fontSize: 13, color: FutechiColors.mutedForeground)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          n.kind == NotifKind.health
                              ? Icons.videocam_outlined
                              : _treatmentIconFor(n.targetId),
                          size: 12,
                          color: FutechiColors.mutedForeground,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(n.time,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: FutechiColors.mutedForeground)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: FutechiColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _treatmentIconFor(String treatmentId) {
  final treatment = getTreatment(treatmentId);
  return treatment != null ? treatmentIcon(treatment) : Icons.healing_outlined;
}
