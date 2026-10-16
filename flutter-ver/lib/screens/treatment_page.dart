import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/treatments.dart';
import '../widgets/case_card.dart';
import '../widgets/section.dart';

/// Port of TreatmentPage from futechi-pages.tsx.
class TreatmentPage extends StatelessWidget {
  const TreatmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        PageTitle(
          title: 'Treatment & Batch',
          description: 'Kelola batch dan jadwal perawatan ayam',
          action: FilledButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Form batch baru siap digunakan'))),
            icon: const Icon(Icons.add),
            label: const Text('Add Batch'),
          ),
        ),
        const SizedBox(height: 32),
        Section(
          title: 'Manajemen Batch',
          child: FutechiCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Batch #24',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: FutechiColors.successSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Aktif',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: FutechiColors.success)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth > 620;
                  final cells = [
                    _meta('UMUR', '65 Hari'),
                    _meta('POPULASI', '1.240 Ayam'),
                    _meta(
                      'LOKASI',
                      'Jl. Bendul Merisi Selatan XI No.51, Bendul Merisi, Kec. Wonocolo, Surabaya',
                    ),
                  ];
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final cell in cells) ...[
                          Expanded(child: cell),
                          if (cell != cells.last) const SizedBox(width: 20),
                        ],
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final cell in cells) ...[cell, const SizedBox(height: 16)],
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Section(
          title: 'Jadwal Perawatan',
          child: LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth > 980 ? 3 : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.05,
              children: [
                for (final (index, t) in treatments.indexed)
                  FutechiCard(
                    onTap: () => Navigator.of(context)
                        .pushNamed('/treatment/detail', arguments: t.id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: FutechiColors.warningSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(
                            index == 2 ? Icons.grass_outlined : Icons.build_outlined,
                            color: FutechiColors.warning,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(t.name,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Target: ${t.target}',
                            style: const TextStyle(
                                fontSize: 13, color: FutechiColors.mutedForeground)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: FutechiColors.secondarySoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(t.dueLabel, style: const TextStyle(fontSize: 12)),
                        ),
                        const Spacer(),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            border: Border.all(color: FutechiColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Lihat Detail',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }

  static Widget _meta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: FutechiColors.mutedForeground)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label == 'LOKASI') ...[
              const Icon(Icons.place_outlined, size: 16),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }
}
