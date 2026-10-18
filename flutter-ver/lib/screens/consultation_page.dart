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
    final isHealthy = status == CaseStatus.healthy;
    final wide = MediaQuery.sizeOf(context).width > 980;

    if (isHealthy) {
      return _buildHealthyView(context, store, wide);
    }
    return _buildActiveView(context, store, status, wide);
  }

  Widget _buildHealthyView(
      BuildContext context, CaseStateStore store, bool wide) {
    final recovery = current.recoveryRecord ??
        RecoveryRecord(
          disease: current.topPossibility.name,
          diagnosedAt: '${current.date}, ${current.time} WIB',
          recoveredAt: '13 Oktober 2026, 11:30 WIB',
          duration: '21 Hari Masa Perawatan',
          treatments: const [
            'Isolasi 14 hari di kandang observasi dengan ventilasi terpisah',
            'Pemberian antibiotik pernapasan Enrofloxacin selama 5 hari berturut-turut',
            'Pemberian larutan vitamin dan elektrolit pada air minum harian',
            'Disinfeksi berkala sangkar dan wadah pakan',
            'Pemberian pakan konsentrat basah berprotein tinggi',
          ],
          vet: 'drh. Hendra Setiawan, Sp.Unggas',
          currentCondition:
              'Nafsu makan telah pulih 100%, pernapasan bersih, bobot tubuh kembali ideal, dan telah berbaur normal di sangkar D-12.',
          notes:
              'Ayam telah dinyatakan sembuh total tanpa komplikasi dan aman dari risiko penularan.',
        );

    final photoCard = FutechiCard(
      padding: EdgeInsets.zero,
      borderColor: FutechiColors.success.withValues(alpha: 0.6),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const StatusBadge(status: CaseStatus.healthy),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: FutechiColors.successSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified,
                              size: 14, color: FutechiColors.success),
                          SizedBox(width: 4),
                          Text(
                            'Selesai Perawatan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: FutechiColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${current.chickenId} · ${current.cage}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  current.symptoms,
                  style: const TextStyle(
                      fontSize: 14, color: FutechiColors.mutedForeground),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FutechiColors.successSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: FutechiColors.success.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: FutechiColors.success, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ayam telah dinyatakan sembuh total dan dipindahkan kembali ke kandang utama.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: FutechiColors.success,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => CaseStateStore.instance
                            .setStatus(current.id, CaseStatus.sick),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FutechiColors.mutedForeground,
                          side: const BorderSide(color: FutechiColors.border),
                        ),
                        child: const Text('Tandai Sakit Lagi'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: FutechiColors.success,
                        ),
                        onPressed: () {},
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Sudah Sehat'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final recoveryDetailCard = FutechiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FutechiColors.successSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: FutechiColors.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rekam Medis & Riwayat Penanganan',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const Text(
                      'Riwayat diagnosis resmi, kronologi sembuh, dan tindakan terapi',
                      style: TextStyle(
                        fontSize: 13,
                        color: FutechiColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 4-box key details
          LayoutBuilder(builder: (context, c) {
            final col2 = c.maxWidth > 500;
            final boxes = [
              _infoTile(
                icon: Icons.coronavirus_outlined,
                label: 'PENYAKIT YANG DIALAMI',
                value: recovery.disease,
                highlightColor: FutechiColors.danger,
              ),
              _infoTile(
                icon: Icons.event_note,
                label: 'KAPAN DIAGNOSA',
                value: recovery.diagnosedAt,
              ),
              _infoTile(
                icon: Icons.task_alt,
                label: 'KAPAN SEMBUH',
                value: recovery.recoveredAt,
                highlightColor: FutechiColors.success,
              ),
              _infoTile(
                icon: Icons.timelapse,
                label: 'DURASI PERAWATAN',
                value: recovery.duration,
              ),
            ];

            if (col2) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: boxes[0]),
                      const SizedBox(width: 12),
                      Expanded(child: boxes[1]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: boxes[2]),
                      const SizedBox(width: 12),
                      Expanded(child: boxes[3]),
                    ],
                  ),
                ],
              );
            }
            return Column(
              children: [
                for (final box in boxes) ...[
                  box,
                  if (box != boxes.last) const SizedBox(height: 12),
                ],
              ],
            );
          }),
          const SizedBox(height: 24),
          const Text(
            'Penanganan & Tindakan yang Telah Diberikan',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final (index, step) in recovery.treatments.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: FutechiColors.successSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: FutechiColors.success,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step,
                      style: const TextStyle(
                        fontSize: 14,
                        color: FutechiColors.foreground,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FutechiColors.secondarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FutechiColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.health_and_safety_outlined,
                        size: 18, color: FutechiColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Kondisi Terkini & Rekomendasi Dokter',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FutechiColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  recovery.currentCondition,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: FutechiColors.foreground,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Catatan: ${recovery.notes}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: FutechiColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dokter Penanggung Jawab: ${recovery.vet}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FutechiColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final postRecoveryCard = FutechiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monitoring Pasca-Sembuh',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Kamera AI Futechi terus memantau nafsu makan dan pola interaksi ayam pada sesi feeding pagi dan sore untuk memastikan kesehatan tetap terjaga prima.',
            style: TextStyle(
                fontSize: 14,
                color: FutechiColors.mutedForeground,
                height: 1.6),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Kembali ke Riwayat Kasus'),
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
          title: 'Rekam Medis & Riwayat Pemulihan',
          description:
              '${current.chickenId} (${current.cage}) · Dinyatakan Sembuh Total',
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
                    recoveryDetailCard,
                    const SizedBox(height: 20),
                    postRecoveryCard,
                  ],
                ),
              ),
            ],
          ),
        ] else ...[
          photoCard,
          const SizedBox(height: 24),
          recoveryDetailCard,
          const SizedBox(height: 24),
          postRecoveryCard,
        ],
      ],
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FutechiColors.secondarySoft.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FutechiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: FutechiColors.mutedForeground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: FutechiColors.mutedForeground,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: highlightColor ?? FutechiColors.foreground,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView(BuildContext context, CaseStateStore store,
      CaseStatus status, bool wide) {
    final suspicion = store.suspicionFor(current.id);

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
                          backgroundColor: status == CaseStatus.sick
                              ? FutechiColors.dangerSoft
                              : null,
                          foregroundColor: status == CaseStatus.sick
                              ? FutechiColors.danger
                              : FutechiColors.foreground,
                          side: BorderSide(
                            color: status == CaseStatus.sick
                                ? FutechiColors.danger
                                : FutechiColors.border,
                            width: status == CaseStatus.sick ? 1.5 : 1.0,
                          ),
                        ),
                        onPressed: () => CaseStateStore.instance
                            .setStatus(current.id, CaseStatus.sick),
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
                        onPressed: status == CaseStatus.sick
                            ? null
                            : () => CaseStateStore.instance
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
                        status == CaseStatus.sick
                            ? 'Status: Terkonfirmasi Sakit'
                            : 'Status: ${caseStatusLabel(status)}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: status == CaseStatus.sick
                                ? FutechiColors.danger
                                : FutechiColors.success),
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
                'assets/images/icon_chatbot.png',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const SizedBox(width: 44, height: 44),
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
                  Text(suspicion.rationale,
                      style: const TextStyle(fontSize: 14)),
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
                              fontSize: 14,
                              color: FutechiColors.mutedForeground)),
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                    begin: 0,
                                    end: possibility.confidence / 100),
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
            style: TextStyle(
                fontSize: 14,
                color: FutechiColors.mutedForeground,
                height: 1.6),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/techi/alert-${current.id}'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Lanjutkan dengan Techi AI'),
            ),
          ),
        ],
      ),
    );
  }
}
