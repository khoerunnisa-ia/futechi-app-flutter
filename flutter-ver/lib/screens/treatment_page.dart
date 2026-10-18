import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../data/batch_data.dart';
import '../data/treatments.dart';
import '../widgets/case_card.dart';
import '../widgets/section.dart';

/// Ikon sesuai jenis perawatan (vaksin, vitamin, sanitasi).
IconData treatmentIcon(Treatment treatment) => switch (treatment.id) {
      'vaksin-nd' => Icons.vaccines_outlined,
      'vitamin-a' => Icons.medication_liquid_outlined,
      'sanitasi' => Icons.sanitizer_outlined,
      _ => Icons.healing_outlined,
    };

/// Port of TreatmentPage from futechi-pages.tsx.
class TreatmentPage extends StatefulWidget {
  const TreatmentPage({super.key});

  @override
  State<TreatmentPage> createState() => _TreatmentPageState();
}

class _TreatmentPageState extends State<TreatmentPage> {
  @override
  void initState() {
    super.initState();
    BatchStore.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    BatchStore.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final batchStore = BatchStore.instance;
    final batches = batchStore.batches;
    final batch = batchStore.selectedBatch;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        PageTitle(
          title: 'Treatment & Batch',
          description: 'Kelola batch dan jadwal perawatan ayam',
          action: FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(FutechiRoutes.batchRegistration),
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
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        decoration: BoxDecoration(
                          color: FutechiColors.secondarySoft.withAlpha(120),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: FutechiColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: batch.id,
                            isExpanded: true,
                            icon: const Icon(Icons.unfold_more,
                                color: FutechiColors.foreground, size: 20),
                            selectedItemBuilder: (context) {
                              return batches.map((b) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    b.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList();
                            },
                            items: [
                              for (final b in batches)
                                DropdownMenuItem(
                                  value: b.id,
                                  child: Row(
                                    children: [
                                      Text(b.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      Text('· ${b.breed}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: FutechiColors.mutedForeground)),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: b.isActive
                                              ? FutechiColors.successSoft
                                              : FutechiColors.secondarySoft,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          b.isActive ? 'Aktif' : 'Selesai',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: b.isActive
                                                ? FutechiColors.success
                                                : FutechiColors.mutedForeground,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (id) {
                              if (id != null) batchStore.selectBatch(id);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: batch.isActive
                            ? FutechiColors.successSoft
                            : FutechiColors.secondarySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        batch.isActive ? 'Aktif' : 'Selesai',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: batch.isActive
                              ? FutechiColors.success
                              : FutechiColors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth > 700;
                  final numberFmt = NumberFormat.decimalPattern('id');
                  final cells = [
                    _meta('JENIS AYAM', batch.breed),
                    _meta('UMUR', '${batch.ageInDays} Hari'),
                    _meta('POPULASI', '${numberFmt.format(batch.chickenCount)} Ayam'),
                    _meta('LOKASI', batch.location),
                  ];
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final cell in cells) ...[
                          Expanded(child: cell),
                          if (cell != cells.last) const SizedBox(width: 16),
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
                for (final t in treatments)
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
                            treatmentIcon(t),
                            color: FutechiColors.warning,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(t.name,
                            style: Theme.of(context).textTheme.titleMedium),
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
