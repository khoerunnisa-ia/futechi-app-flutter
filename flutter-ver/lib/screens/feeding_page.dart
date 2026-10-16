import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../widgets/page_title.dart';
import '../widgets/case_card.dart';

/// Port of FeedingPage from futechi-pages.tsx.
class FeedingPage extends StatefulWidget {
  const FeedingPage({super.key});

  @override
  State<FeedingPage> createState() => _FeedingPageState();
}

class _FeedingItem {
  _FeedingItem(this.time, this.name, this.enabled);
  final String time;
  final String name;
  bool enabled;
}

class _FeedingPageState extends State<FeedingPage> {
  final List<_FeedingItem> _items = [
    _FeedingItem('06:00', 'Sesi Pagi', false),
    _FeedingItem('7:00', 'Sesi Pagi', true),
    _FeedingItem('16:30', 'Sesi Sore', true),
    _FeedingItem('17:00', 'Sesi Sore', false),
  ];

  void _addSchedule() {
    setState(() {
      _items.add(_FeedingItem('22:00', 'Sesi Tambahan', true));
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Jadwal baru ditambahkan')));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 620;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        PageTitle(
          title: 'Jadwal Pakan Otomatis',
          description: 'Atur sesi feeding Kandang',
          action: FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feeding berhasil dimulai')),
              );
            },
            icon: const Icon(Icons.rice_bowl_outlined),
            label: const Text('Beri Pakan Sekarang'),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (var i = 0; i < _items.length; i++)
              SizedBox(
                width: wide ? (MediaQuery.sizeOf(context).width - 40 - 16) / 2 : double.infinity,
                child: FutechiCard(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _items[i].time,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: _items[i].enabled
                                    ? FutechiColors.foreground
                                    : FutechiColors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(_items[i].name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: FutechiColors.mutedForeground)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _items[i].enabled,
                        onChanged: (value) =>
                            setState(() => _items[i].enabled = value),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: FutechiColors.primary,
            side: const BorderSide(color: FutechiColors.primary),
            minimumSize: const Size(double.infinity, 56),
          ),
          onPressed: _addSchedule,
          icon: const Icon(Icons.add),
          label: const Text('Tambah Jadwal'),
        ),
      ],
    );
  }
}
