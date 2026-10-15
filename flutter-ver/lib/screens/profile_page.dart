import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Port of ProfilePage from futechi-pages.tsx.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _selected;

  static const _rows = [
    (Icons.account_circle_outlined, 'Edit Profil'),
    (Icons.lock_outline, 'Ganti Kata Sandi'),
    (Icons.tune_outlined, 'Pengaturan Notifikasi'),
    (Icons.translate_outlined, 'Bahasa Indonesia'),
    (Icons.verified_user_outlined, 'Kebijakan Privasi'),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            Column(
              children: [
                const CircleAvatar(
                  radius: 48,
                  backgroundColor: FutechiColors.primary,
                  child: Text('AF',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: FutechiColors.onPrimary)),
                ),
                const SizedBox(height: 16),
                const Text('Mulyo',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: FutechiColors.secondarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Manajer Kandang',
                      style: TextStyle(color: FutechiColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: FutechiColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: FutechiColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (index, (icon, label)) in _rows.indexed)
                    InkWell(
                      onTap: () => _openRow(label),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: index == _rows.length - 1
                              ? null
                              : const Border(
                                  bottom: BorderSide(color: FutechiColors.border)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: FutechiColors.secondarySoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icon, color: FutechiColors.primary, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(label,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            const Icon(Icons.chevron_right,
                                size: 18, color: FutechiColors.mutedForeground),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: FutechiColors.danger,
                side: const BorderSide(color: FutechiColors.danger),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sesi tetap aktif pada purwarupa ini')),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Keluar Akun'),
            ),
          ],
        ),
      ),
    );
  }

  void _openRow(String label) {
    setState(() => _selected = label);
    _showDialog();
  }

  void _showDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_selected ?? ''),
        content: const Text(
          'Pilihan ini siap disesuaikan. Perubahan pada purwarupa akan tersimpan selama sesi berlangsung.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('${_selected!} diperbarui')));
              Navigator.of(dialogContext).pop();
              setState(() => _selected = null);
            },
            child: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );
  }
}
