import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/case_state.dart';
import '../data/health_case.dart';
import '../widgets/case_card.dart';
import '../widgets/page_title.dart';
import '../widgets/section.dart';

/// Port of HistoryPage from futechi-pages.tsx (session filter + date picker).
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

enum _SessionFilter { all, morning, evening }

class _HistoryPageState extends State<HistoryPage> {
  _SessionFilter _session = _SessionFilter.all;
  DateTime? _date;
  DateTime? _draftDate;

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

  static const _stats = [
    ('Ayam dianalisis', '1,240', '100% populasi terpantau', false),
    ('Ayam sehat', '1,237', 'Skor kesehatan 92%', false),
    ('Perlu perhatian', '3', '3 peringatan aktif', true),
  ];

  List<HealthCase> get _filteredCases {
    final store = CaseStateStore.instance;
    return sortedHealthCases.where((item) {
      final dateOk = _date == null ||
          item.dateKey == _date!.toIso8601String().substring(0, 10);
      final sessionOk = _session == _SessionFilter.all ||
          (_session == _SessionFilter.morning &&
              item.session == FeedingSession.morning) ||
          (_session == _SessionFilter.evening &&
              item.session == FeedingSession.evening);
      return dateOk && sessionOk;
    }).where((_) {
      return store.loaded || true; // store is optional for the list
    }).toList();
  }

  Future<void> _pickDate() async {
    final availableDates = sortedHealthCases.map((c) => c.dateKey).toSet();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      selectableDayPredicate: (day) =>
          availableDates.contains(day.toIso8601String().substring(0, 10)),
      helpText: 'Pilih tanggal analisis',
      cancelText: 'Reset',
      confirmText: 'Terapkan',
    );
    if (picked == null) {
      // "Reset" was pressed (cancelled).
      if (mounted) setState(() => _date = null);
      return;
    }
    setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final store = CaseStateStore.instance;
    final filtered = _filteredCases;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        const PageTitle(
          title: 'Riwayat Kesehatan',
          description: 'Analisis kamera dan anomali sensor peternakan',
        ),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > 800;
          final cards = [
            for (final (title, value, note, danger) in _stats)
              FutechiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: FutechiColors.mutedForeground)),
                    const SizedBox(height: 8),
                    Text(value,
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: danger ? FutechiColors.danger : null)),
                    const SizedBox(height: 8),
                    Text(note,
                        style: const TextStyle(
                            fontSize: 12, color: FutechiColors.mutedForeground)),
                  ],
                ),
              ),
          ];
          if (wide) {
            return Row(
              children: [
                for (final card in cards) ...[
                  Expanded(child: card),
                  if (card != cards.last) const SizedBox(width: 16),
                ],
              ],
            );
          }
          return Column(
            children: [
              for (final card in cards) ...[card, const SizedBox(height: 16)],
            ],
          );
        }),
        const SizedBox(height: 32),
        Section(
          title: 'Status Kesehatan Aktif',
          action: TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed('/history/health-alerts'),
            child: const Text('Lihat selengkapnya'),
          ),
          child: Column(
            children: [
              for (final item
                  in sortedHealthCases.where((c) => store.statusFor(c) != CaseStatus.healthy).take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CaseCard(healthCase: item, status: store.statusFor(item)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Section(
          title: 'Riwayat Analisis Kesehatan',
          action: Row(
            children: [
              _sessionToggle(_SessionFilter.all, 'Semua'),
              const SizedBox(width: 6),
              _sessionToggle(_SessionFilter.morning, 'Pagi'),
              const SizedBox(width: 6),
              _sessionToggle(_SessionFilter.evening, 'Sore'),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _pickDate,
                icon: Badge(
                  isLabelVisible: _date != null,
                  child: const Icon(Icons.calendar_month_outlined),
                ),
                tooltip: 'Pilih tanggal analisis',
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_session == _SessionFilter.all ? "Semua sesi" : _session == _SessionFilter.morning ? "Feeding pagi" : "Feeding sore"} · ${_date == null ? "Semua tanggal" : _formatDate(_date!)}',
                style: const TextStyle(
                    fontSize: 14, color: FutechiColors.mutedForeground),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth > 980
                    ? 3
                    : constraints.maxWidth > 620
                        ? 2
                        : 1;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.78,
                  children: [
                    for (final item in filtered)
                      CaseCard(healthCase: item, status: store.statusFor(item), imageTop: true),
                  ],
                );
              }),
              if (filtered.isEmpty)
                FutechiCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: const [
                      Icon(Icons.camera_alt_outlined,
                          color: FutechiColors.mutedForeground),
                      SizedBox(height: 12),
                      Text('Tidak ada temuan',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text(
                        'Tidak ada ayam dengan temuan analisis pada waktu ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: FutechiColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sessionToggle(_SessionFilter value, String label) {
    final selected = _session == value;
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor:
            selected ? FutechiColors.primary : FutechiColors.card,
        foregroundColor:
            selected ? FutechiColors.onPrimary : FutechiColors.foreground,
        minimumSize: const Size(0, 36),
        side: BorderSide(color: FutechiColors.border),
      ),
      onPressed: () => setState(() => _session = value),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
