import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/case_state.dart';
import '../data/health_case.dart';
import '../widgets/case_card.dart';
import '../widgets/page_title.dart';

/// Port of ConsultationPage from futechi-pages.tsx.
/// Also serves /history/feeding-analysis/:analysisId and /history/report/:reportId.
class ConsultationPage extends StatefulWidget {
  const ConsultationPage({super.key, required this.alertId});

  final String alertId;

  @override
  State<ConsultationPage> createState() => _ConsultationPageState();
}

class _ConsultationPageState extends State<ConsultationPage> {
  late HealthCase current;

  @override
  void initState() {
    super.initState();
    current = getHealthCase(widget.alertId);
    CaseStateStore.instance.load();
    CaseStateStore.instance.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant ConsultationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alertId != widget.alertId) {
      current = getHealthCase(widget.alertId);
    }
  }

  @override
  void dispose() {
    CaseStateStore.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = CaseStateStore.instance;
    final status = store.statusFor(current);
    final suspicion = store.suspicionFor(current.id);
    final wide = MediaQuery.sizeOf(context).width > 980;

    final photoCard = FutechiCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: caseImage(current.image, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(status: status),
                const SizedBox(height: 16),
                Text(current.cage,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(current.symptoms,
                    style: const TextStyle(
                        fontSize: 14, color: FutechiColors.mutedForeground)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: status == CaseStatus.sick
                              ? FutechiColors.danger
                              : FutechiColors.foreground,
                          side: BorderSide(
                            color: status == CaseStatus.sick
                                ? FutechiColors.danger
                                : FutechiColors.border,
                          ),
                        ),
                        onPressed: () =>
                            CaseStateStore.instance.setStatus(current.id, CaseStatus.sick),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status == CaseStatus.sick)
                              const Icon(Icons.check, size: 18),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text('Konfirmasi Sakit',
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: status == CaseStatus.healthy
                              ? FutechiColors.success
                              : FutechiColors.primary,
                        ),
                        onPressed: () => CaseStateStore.instance
                            .setStatus(current.id, CaseStatus.healthy),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status == CaseStatus.healthy)
                              const Icon(Icons.check, size: 18),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text('Tandai Sehat',
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (status != CaseStatus.pending)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Text(
                        'Status tersimpan: ${caseStatusLabel(status)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: FutechiColors.success),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final analysisCard = FutechiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/techi-mascot.png',
                width: 48,
                height: 48,
                errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kemungkinan dari Analisis Visual',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Text(
                      'Hasil ini bukan diagnosis pasti. Konfirmasi dengan pemeriksaan dokter hewan.',
                      style: TextStyle(
                          fontSize: 13, color: FutechiColors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (suspicion != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FutechiColors.successSoft,
                border: Border.all(color: FutechiColors.success),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HASIL PEMERIKSAAN GEJALA',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: FutechiColors.success)),
                  const SizedBox(height: 4),
                  Text(suspicion.disease,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('Kecocokan ${suspicion.confidence}%',
                      style: const TextStyle(
                          fontSize: 14,
                          color: FutechiColors.success,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(suspicion.rationale, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Cara mitigasi',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final item in suspicion.mitigation)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              fontSize: 14, color: FutechiColors.mutedForeground)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FutechiColors.warningSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saran obat/penanganan',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: FutechiColors.warning)),
                  const SizedBox(height: 8),
                  Text(suspicion.medication,
                      style: const TextStyle(
                          fontSize: 14, color: FutechiColors.mutedForeground)),
                ],
              ),
            ),
          ] else
            for (final (index, possibility) in current.possibilities.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: index == 0
                        ? FutechiColors.secondarySoft.withAlpha(160)
                        : FutechiColors.secondarySoft.withAlpha(100),
                    border: Border.all(
                      color: index == 0
                          ? FutechiColors.primary
                          : FutechiColors.border,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: index == 0
                            ? FutechiColors.primary
                            : FutechiColors.card,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: index == 0
                                ? FutechiColors.onPrimary
                                : FutechiColors.mutedForeground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(possibility.name,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: possibility.confidence / 100),
                                duration: const Duration(milliseconds: 500),
                                builder: (context, value, _) =>
                                    LinearProgressIndicator(value: value),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${possibility.confidence}%',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: index == 0
                                  ? FutechiColors.primary
                                  : FutechiColors.mutedForeground)),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Kembali ke History'),
        ),
        const SizedBox(height: 8),
        PageTitle(
          title: 'Konsultasi Peringatan',
          description: '${current.cage} · Terdeteksi ${current.date}',
        ),
        const SizedBox(height: 24),
        if (wide) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: photoCard),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    analysisCard,
                    const SizedBox(height: 20),
                    _nextStepsCard(context),
                  ],
                ),
              ),
            ],
          ),
        ] else ...[
          photoCard,
          const SizedBox(height: 24),
          analysisCard,
          const SizedBox(height: 24),
          _nextStepsCard(context),
        ],
      ],
    );
  }

  Widget _nextStepsCard(BuildContext context) {
    return FutechiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Langkah Berikutnya',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Buka konsultasi Techi untuk meninjau checklist observasi dan mencatat tindakan pada kasus ini.',
            style: TextStyle(fontSize: 14, color: FutechiColors.mutedForeground, height: 1.6),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context)
                  .pushNamed('/techi/alert-${current.id}'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Lanjutkan dengan Techi AI'),
            ),
          ),
        ],
      ),
    );
  }
}
