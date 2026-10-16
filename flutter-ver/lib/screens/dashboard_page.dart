import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../widgets/case_card.dart';
import '../widgets/section.dart';

/// Port of DashboardPage from futechi-pages.tsx.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _treatmentDone = false;

  static const _sensorCards = [
    (
      'Suhu',
      '31.2°C',
      'Rentang ideal 28–32°C',
      '↑ 0.8°C dari kemarin',
      Icons.thermostat_outlined,
      FutechiColors.dangerSoft,
      FutechiColors.danger,
    ),
    (
      'Kelembapan',
      '71%',
      'Rentang ideal 60–75%',
      '↑ 2% dari kemarin',
      Icons.water_drop_outlined,
      FutechiColors.secondarySoft,
      FutechiColors.primary,
    ),
    (
      'Amonia',
      '5 ppm',
      'Aman di bawah 20 ppm',
      '↓ 1 ppm dari kemarin',
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
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 800 ? 3 : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: columns == 3 ? 1.1 : 2.4,
              children: [
                for (final card in _sensorCards)
                  FutechiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: card.$6,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(card.$5, color: card.$7),
                            ),
                            Text(
                              card.$4,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: FutechiColors.success,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(card.$1,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(card.$2,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800)),
                        Text(card.$3,
                            style: const TextStyle(
                                fontSize: 12,
                                color: FutechiColors.mutedForeground)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _buildBarnCard(context),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 980) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildFeedingCard(context)),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: _buildDailySummary(context)),
                ],
              );
            }
            return Column(
              children: [
                _buildFeedingCard(context),
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
      child: SizedBox(
        height: 310,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/futechi-hero-chickens.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: FutechiColors.foreground),
            ),
            DecoratedBox(
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
            ),
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    const Text(
                      'Pusat Informasi Peternakan',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: FutechiColors.background,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Monitoring real-time untuk peternakan yang lebih sehat dan produktif.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    const Row(
                      children: [
                        Icon(Icons.schedule_outlined, size: 16, color: Colors.white60),
                        SizedBox(width: 8),
                        Text('Update terakhir: Hari ini, 07:41',
                            style: TextStyle(fontSize: 12, color: Colors.white60)),
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
              errorBuilder: (_, __, ___) => Container(color: FutechiColors.secondarySoft),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: _overlayChip(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    '● Kandang Bendul Merisi',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: FutechiColors.success),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
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
          BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
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
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: FutechiColors.primary)),
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
                color: done ? FutechiColors.success : FutechiColors.mutedForeground,
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
              const Text('Jadwal Feeding',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Feeding dimulai'),
                    action: SnackBarAction(label: 'OK', onPressed: () {}),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Jalankan Feeding Sekarang'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Section(title: 'Ringkasan harian', child: SizedBox.shrink()),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            for (final (icon, value, label) in _dailyCards)
              FutechiCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: FutechiColors.primary),
                    const Spacer(),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 12, color: FutechiColors.mutedForeground)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Section(
          title: 'Perawatan & Kesehatan',
          child: FutechiCard(
            child: Column(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context)
                      .pushNamed(FutechiRoutes.treatmentDetail, arguments: 'vaksin-nd'),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: FutechiColors.dangerSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.build_outlined, color: FutechiColors.danger),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vaksinasi Newcastle Disease',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            Text('Besok, 08:00 WIB',
                                style: TextStyle(
                                    fontSize: 13, color: FutechiColors.mutedForeground)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: FutechiColors.dangerSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Mendesak',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: FutechiColors.danger)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: _treatmentDone
                        ? null
                        : () {
                            setState(() => _treatmentDone = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Perawatan dikonfirmasi selesai')),
                            );
                          },
                    child: _treatmentDone
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check),
                              SizedBox(width: 8),
                              Text('Selesai dikonfirmasi'),
                            ],
                          )
                        : const Text('Konfirmasi Selesai'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
