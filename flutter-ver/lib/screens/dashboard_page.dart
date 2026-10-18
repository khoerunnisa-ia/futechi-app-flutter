import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../data/treatments.dart';
import '../widgets/case_card.dart';
import '../widgets/cctv_player.dart';
import '../widgets/section.dart';
import 'treatment_page.dart' show treatmentIcon;

/// Jam WIB (UTC+7) dalam format `HH:mm:ss`, tidak bergantung zona waktu perangkat.
String formatWibClock(DateTime now) =>
    DateFormat('HH:mm:ss').format(now.toUtc().add(const Duration(hours: 7)));

/// Port of DashboardPage from futechi-pages.tsx.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  TreatmentStore get _treatmentStore => TreatmentStore.instance;

  @override
  void initState() {
    super.initState();
    _treatmentStore.load();
    _treatmentStore.addListener(_onTreatmentsChanged);
  }

  @override
  void dispose() {
    _treatmentStore.removeListener(_onTreatmentsChanged);
    super.dispose();
  }

  void _onTreatmentsChanged() {
    if (mounted) setState(() {});
  }

  static const _sensorCards = [
    (
      'Suhu',
      '31.2°C',
      'Rentang ideal 28–32°C',
      Icons.thermostat_outlined,
      FutechiColors.dangerSoft,
      FutechiColors.danger,
    ),
    (
      'Kelembapan',
      '71%',
      'Rentang ideal 60–75%',
      Icons.water_drop_outlined,
      FutechiColors.secondarySoft,
      FutechiColors.primary,
    ),
    (
      'Amonia',
      '5 ppm',
      'Aman di bawah 20 ppm',
      Icons.eco_outlined,
      FutechiColors.successSoft,
      FutechiColors.success,
    ),
  ];

  static const _dailyCards = [
    (Icons.egg_outlined, '1970', 'Telur diproduksi'),
    (Icons.favorite_border_outlined, '99.3%', 'Ayam sehat'),
    (Icons.monitor_heart_outlined, '3', 'Anomali'),
    (Icons.grass_outlined, '60 ton', 'Pakan terpakai'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        _buildHero(context),
        const SizedBox(height: 24),

        // ─── Sensor cards (Suhu, Kelembapan, Amonia) ───
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 800 ? 3 : 1;
            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 16,
                mainAxisExtent: 88,
              ),
              children: [
                for (final card in _sensorCards)
                  FutechiCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: card.$5,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(card.$4, color: card.$6),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.$1,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                card.$3,
                                softWrap: true,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.25,
                                  color: FutechiColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            card.$2,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // ─── Barn overview card (futechi-barn.jpg) — TETAP UTUH ───
        _buildBarnCard(context),
        const SizedBox(height: 24),

        // ─── Row 1: Jadwal Feeding | CCTV Pemantauan Kandang ───
        // Sesuai React: grid gap-6 lg:grid-cols-2 (baris 287–351)
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 980) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildFeedingCard(context)),
                  const SizedBox(width: 24),
                  const Expanded(child: CctvCard()),
                ],
              );
            }
            return Column(
              children: [
                _buildFeedingCard(context),
                const SizedBox(height: 24),
                const CctvCard(),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // ─── Row 2: Perawatan & Kesehatan | Ringkasan harian ───
        // Sesuai React: grid gap-6 lg:grid-cols-[1.45fr_1fr] (baris 352–400)
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 980) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildTreatmentSection(context)),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: _buildDailySummary(context)),
                ],
              );
            }
            return Column(
              children: [
                _buildTreatmentSection(context),
                const SizedBox(height: 24),
                _buildDailySummary(context),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildHero(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 310),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/futechi-hero-chickens.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: FutechiColors.foreground),
              ),
            ),
            Positioned.fill(
                child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    FutechiColors.foreground.withAlpha(235),
                    FutechiColors.foreground.withAlpha(140),
                    Colors.transparent,
                  ],
                ),
              ),
            )),
            Container(
              constraints: const BoxConstraints(minHeight: 310),
              padding: const EdgeInsets.all(32),
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: FutechiColors.success,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '● Kondisi Baik',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: FutechiColors.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pusat Informasi Peternakan',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(color: FutechiColors.background),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Monitoring real-time untuk peternakan yang lebih sehat dan produktif.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    const Row(
                      children: [
                        Icon(Icons.schedule_outlined,
                            size: 16, color: Colors.white60),
                        SizedBox(width: 8),
                        WibClock(
                            style:
                                TextStyle(fontSize: 12, color: Colors.white60)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarnCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 8.2,
            child: Image.asset(
              'assets/images/futechi-barn.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: FutechiColors.secondarySoft),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: _overlayChip(
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '● Kandang Bendul Merisi',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: FutechiColors.success),
                  ),
                  Text('1,240 ekor ayam',
                      style: TextStyle(
                          fontSize: 12, color: FutechiColors.mutedForeground)),
                ],
              ),
            ),
          ),
          Positioned(
            right: 32,
            top: 0.18 * 310,
            child: _overlayChip(
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Kelembapan', style: TextStyle(fontSize: 12)),
                  Text('71%', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0.32 * 600,
            bottom: 0.16 * 310,
            child: _overlayChip(
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Suhu', style: TextStyle(fontSize: 12)),
                  Text('31.2°C', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(FutechiRoutes.history),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Lihat detail'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overlayChip(Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FutechiColors.card.withAlpha(242),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFeedingCard(BuildContext context) {
    Widget row(String time, String name, String session, String state) {
      final done = state == 'Selesai';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text(time,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: FutechiColors.primary)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pakan Grower',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('± 20 kg · Sesi $session',
                      style: const TextStyle(
                          fontSize: 12, color: FutechiColors.mutedForeground)),
                ],
              ),
            ),
            Text(
              state,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: done
                    ? FutechiColors.success
                    : FutechiColors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    return FutechiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Jadwal Feeding',
                  style: Theme.of(context).textTheme.titleLarge),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: FutechiColors.warningSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Hari ini',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FutechiColors.warning)),
              ),
            ],
          ),
          const Divider(height: 24),
          row('07:00', 'Pakan Grower', 'Pagi', 'Selesai'),
          const Divider(height: 1),
          row('16:00', 'Pakan Grower', 'Sore', 'Menunggu'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(FutechiRoutes.feeding),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Jadwal Feeding'),
            ),
          ),
        ],
      ),
    );
  }

  /// Ringkasan harian — 4 kartu 2×2
  /// Sesuai React: Section "Ringkasan harian" (baris 389–399)
  Widget _buildDailySummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Section(title: 'Ringkasan harian', child: SizedBox.shrink()),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 72,
          ),
          children: [
            for (final (icon, value, label) in _dailyCards)
              FutechiCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, color: FutechiColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(value,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                          ),
                          Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: FutechiColors.mutedForeground)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Perawatan & Kesehatan — 2 jadwal terdekat dari [TreatmentStore].
  /// Sesuai React: Section kiri di Row 2 (baris 352–388)
  Widget _buildTreatmentSection(BuildContext context) {
    final upcoming = _treatmentStore.upcoming(limit: 2);
    return Section(
      title: 'Perawatan & Kesehatan',
      action: TextButton(
        onPressed: () =>
            Navigator.of(context).pushNamed(FutechiRoutes.treatment),
        child: const Text('Lihat semua'),
      ),
      child: FutechiCard(
        child: upcoming.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Semua perawatan sudah selesai.',
                    style: TextStyle(color: FutechiColors.mutedForeground)),
              )
            : Column(
                children: [
                  for (final (index, t) in upcoming.indexed) ...[
                    if (index > 0) const Divider(height: 32),
                    _buildTreatmentRow(context, t),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildTreatmentRow(BuildContext context, Treatment t) {
    final urgent = t.status == TreatmentStatus.mendesak;
    final snoozed = _treatmentStore.reminderFor(t.id).snoozedUntil;
    return Column(
      children: [
        InkWell(
          key: ValueKey('treatment_row_${t.id}'),
          onTap: () => Navigator.of(context)
              .pushNamed(FutechiRoutes.treatmentDetail, arguments: t.id),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: urgent
                        ? FutechiColors.dangerSoft
                        : FutechiColors.secondarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(treatmentIcon(t),
                      color: urgent
                          ? FutechiColors.danger
                          : FutechiColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                          snoozed != null
                              ? 'Ditunda hingga ${DateFormat('d MMM, HH:mm').format(snoozed)}'
                              : t.schedule,
                          style: const TextStyle(
                              fontSize: 13,
                              color: FutechiColors.mutedForeground)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgent
                        ? FutechiColors.dangerSoft
                        : FutechiColors.secondarySoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(urgent ? 'Mendesak' : 'Terjadwal',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: urgent
                              ? FutechiColors.danger
                              : FutechiColors.primary)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TreatmentSnoozeButton(treatment: t),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: ValueKey('treatment_done_${t.id}'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await _treatmentStore.markDone(t.id);
                  messenger.showSnackBar(
                      SnackBar(content: Text('${t.name} ditandai selesai')));
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Tandai Selesai'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tombol "Tunda Reminder" dengan pilihan 1 jam / 3 jam / besok.
class TreatmentSnoozeButton extends StatelessWidget {
  const TreatmentSnoozeButton({super.key, required this.treatment});

  final Treatment treatment;

  static const options = [
    ('1 jam', Duration(hours: 1)),
    ('3 jam', Duration(hours: 3)),
    ('Besok', Duration(hours: 24)),
  ];

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final (label, duration) in options)
          MenuItemButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await TreatmentStore.instance.snooze(treatment.id, duration);
              messenger.showSnackBar(SnackBar(
                  content: Text('Reminder ${treatment.name} ditunda $label')));
            },
            child: Text(label),
          ),
      ],
      builder: (context, controller, _) => OutlinedButton.icon(
        key: ValueKey('treatment_snooze_${treatment.id}'),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.snooze_outlined, size: 18),
        label: const Text('Tunda Reminder'),
      ),
    );
  }
}

/// Jam live WIB untuk hero dashboard, diperbarui setiap detik.
class WibClock extends StatefulWidget {
  const WibClock({super.key, this.style});

  final TextStyle? style;

  @override
  State<WibClock> createState() => _WibClockState();
}

class _WibClockState extends State<WibClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('${formatWibClock(_now)} · WIB', style: widget.style);
  }
}
