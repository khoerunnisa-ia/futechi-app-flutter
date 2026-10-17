import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';
import '../data/treatments.dart';
import '../widgets/case_card.dart';

/// Port of TreatmentDetailPage from futechi-extra-pages.tsx.
class TreatmentDetailPage extends StatefulWidget {
  const TreatmentDetailPage({super.key, required this.treatmentId});

  final String treatmentId;

  @override
  State<TreatmentDetailPage> createState() => _TreatmentDetailPageState();
}

class _TreatmentDetailPageState extends State<TreatmentDetailPage> {
  @override
  void initState() {
    super.initState();
    TreatmentStore.instance.load();
    TreatmentStore.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    TreatmentStore.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Tautan tidak dapat dibuka')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final treatment = getTreatment(widget.treatmentId);
    if (treatment == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FutechiCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Text('Treatment tidak ditemukan.',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kembali ke Treatment'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    final store = TreatmentStore.instance;
    final reminder = store.reminderFor(treatment.id);
    final next = reminder.snoozedUntil != null
        ? _formatDateTime(reminder.snoozedUntil!)
        : treatment.schedule;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Kembali ke Treatment'),
        ),
        const SizedBox(height: 8),
        FutechiCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: treatment.status == TreatmentStatus.mendesak
                      ? FutechiColors.dangerSoft
                      : FutechiColors.secondarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  treatment.status == TreatmentStatus.mendesak
                      ? 'Mendesak'
                      : 'Terjadwal',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: treatment.status == TreatmentStatus.mendesak
                        ? FutechiColors.danger
                        : FutechiColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(treatment.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              Text(
                '${treatment.schedule} · ${treatment.target}',
                style: const TextStyle(color: FutechiColors.mutedForeground),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('treatment_detail_done'),
                onPressed: store.isDone(treatment.id)
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await store.markDone(treatment.id);
                        messenger.showSnackBar(SnackBar(
                            content: Text('${treatment.name} ditandai selesai')));
                      },
                icon: const Icon(Icons.check, size: 18),
                label: Text(store.isDone(treatment.id)
                    ? 'Sudah Selesai'
                    : 'Tandai Selesai'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          final info = FutechiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medication_outlined, color: FutechiColors.primary),
                    const SizedBox(width: 8),
                    Text('Informasi Obat',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 16),
                _meta('PRODUK', treatment.product),
                _meta('KANDUNGAN', treatment.ingredient),
                _meta('BENTUK SEDIAAN', treatment.form),
              ],
            ),
          );
          final dose = FutechiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.vaccines_outlined, color: FutechiColors.primary),
                    const SizedBox(width: 8),
                    Text('Dosis',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 16),
                Text(treatment.dosage,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FutechiColors.warningSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(treatment.safety,
                      style: const TextStyle(
                          fontSize: 14, color: FutechiColors.warning)),
                ),
              ],
            ),
          );
          if (constraints.maxWidth > 620) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: info),
                const SizedBox(width: 24),
                Expanded(child: dose),
              ],
            );
          }
          return Column(
            children: [
              info,
              const SizedBox(height: 24),
              dose,
            ],
          );
        }),
        const SizedBox(height: 24),
        FutechiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Panduan Pemberian',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              for (final (index, step) in treatment.steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: FutechiColors.primary,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: FutechiColors.onPrimary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(step,
                              style: const TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, constraints) {
                final buy = FilledButton.icon(
                  onPressed: () => _openUrl(treatment.buyUrl),
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('Beli Produk'),
                );
                final tutorial = OutlinedButton.icon(
                  onPressed: () => _openUrl(treatment.tutorialUrl),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Tonton Tutorial'),
                );
                if (constraints.maxWidth > 480) {
                  return Row(
                    children: [
                      Expanded(child: buy),
                      const SizedBox(width: 12),
                      Expanded(child: tutorial),
                    ],
                  );
                }
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: buy),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: tutorial),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FutechiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined,
                                color: FutechiColors.primary),
                            const SizedBox(width: 8),
                            Text('Reminder',
                                style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reminder.enabled
                              ? 'Pengingat berikutnya: $next'
                              : 'Reminder dinonaktifkan',
                          style: const TextStyle(
                              fontSize: 14, color: FutechiColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: reminder.enabled,
                    onChanged: (enabled) {
                      TreatmentStore.instance.updateReminder(
                        treatment.id,
                        Reminder(enabled: enabled),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            enabled ? 'Reminder diaktifkan' : 'Reminder dinonaktifkan'),
                      ));
                    },
                  ),
                ],
              ),
              if (reminder.enabled) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Tunda Reminder:',
                        style: TextStyle(
                            fontSize: 14, color: FutechiColors.mutedForeground)),
                    OutlinedButton(
                      onPressed: () => TreatmentStore.instance
                          .snooze(treatment.id, const Duration(hours: 1)),
                      child: const Text('1 jam'),
                    ),
                    OutlinedButton(
                      onPressed: () => TreatmentStore.instance
                          .snooze(treatment.id, const Duration(hours: 3)),
                      child: const Text('3 jam'),
                    ),
                    OutlinedButton(
                      onPressed: () => TreatmentStore.instance
                          .snooze(treatment.id, const Duration(hours: 24)),
                      child: const Text('Besok'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Data obat, dosis, dan link merupakan contoh. Selalu ikuti label produk dan arahan dokter hewan.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: FutechiColors.mutedForeground),
        ),
      ],
    );
  }

  static Widget _meta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: FutechiColors.mutedForeground)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

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
