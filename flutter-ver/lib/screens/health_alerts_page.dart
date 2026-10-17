import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/case_state.dart';
import '../data/health_case.dart';
import '../widgets/case_card.dart';

/// Port of HealthAlertsPage from futechi-pages.tsx.
class HealthAlertsPage extends StatefulWidget {
  const HealthAlertsPage({super.key});

  @override
  State<HealthAlertsPage> createState() => _HealthAlertsPageState();
}

class _HealthAlertsPageState extends State<HealthAlertsPage> {
  @override
  void initState() {
    super.initState();
    CaseStateStore.instance.load();
    CaseStateStore.instance.addListener(_refresh);
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
    final activeCases = sortedHealthCases
        .where((item) => store.statusFor(item) != CaseStatus.healthy)
        .toList();
    final waiting = activeCases
        .where((item) => store.statusFor(item) == CaseStatus.pending)
        .length;
    final sick = activeCases
        .where((item) => store.statusFor(item) == CaseStatus.sick)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Kembali ke History'),
        ),
        const SizedBox(height: 8),
        Text(
          'Kasus Kesehatan Aktif',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Text(
          'Ayam sakit dan temuan yang masih menunggu konfirmasi',
          style: TextStyle(fontSize: 14, color: FutechiColors.mutedForeground),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: FutechiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MENUNGGU KONFIRMASI',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: FutechiColors.mutedForeground)),
                    const SizedBox(height: 8),
                    Text(waiting.toString(),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(color: FutechiColors.warning)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FutechiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SAKIT',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: FutechiColors.mutedForeground)),
                    const SizedBox(height: 8),
                    Text(sick.toString(),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(color: FutechiColors.danger)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        for (final item in activeCases)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CaseCard(healthCase: item, status: store.statusFor(item)),
          ),
      ],
    );
  }
}
