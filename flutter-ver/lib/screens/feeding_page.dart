import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/feeder.dart';
import '../data/feeder_link.dart';
import '../widgets/page_title.dart';
import '../widgets/case_card.dart';

/// Port of FeedingPage from futechi-pages.tsx.
class FeedingPage extends StatefulWidget {
  const FeedingPage({super.key, this.controller, this.link});

  /// Defaults to [FeederController.instance] / [sharedFeederLink].
  final FeederController? controller;
  final FeederLink? link;

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

  late final FeederController _controller =
      widget.controller ?? FeederController.instance;
  late final FeederLink _link = widget.link ?? sharedFeederLink;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _link.onMessage = _controller.handleMqttMessage;
    // Auto-connect saat membuka FeedingPage jika belum pernah terkoneksi
    if (_link.state == FeederLinkState.disconnected) {
      _link.autoConnect();
    }
  }

  bool get _feedBusy =>
      _sending || _controller.feeding || _controller.systemRunning;

  Future<void> _feedNow() async {
    if (_feedBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    final simulation = _controller.feedNow();
    final sent = await _link.publishFeedNow();
    if (mounted) setState(() => _sending = false);
    messenger.showSnackBar(SnackBar(
      content: Text(sent
          ? 'Perintah pakan dikirim ke feeder'
          : 'Feeder tidak terhubung, menjalankan simulasi saja'),
    ));
    await simulation;
  }

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
          action: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => FilledButton.icon(
              onPressed: _feedBusy ? null : _feedNow,
              icon: const Icon(Icons.rice_bowl_outlined),
              label: const Text('Beri Pakan Sekarang'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ListenableBuilder(
          listenable: Listenable.merge([_controller, _link]),
          builder: (context, _) =>
              _FeederStatusCard(controller: _controller, link: _link),
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

class _FeederStatusCard extends StatelessWidget {
  const _FeederStatusCard({required this.controller, required this.link});

  final FeederController controller;
  final FeederLink link;

  static String _motorLabel(bool running, bool dir) =>
      running ? 'Berjalan · ${dir ? 'Kanan' : 'Kiri'}' : 'Berhenti';

  static String _linkLabel(FeederLinkState state) => switch (state) {
        FeederLinkState.connected => 'Terhubung',
        FeederLinkState.connecting => 'Menghubungkan...',
        FeederLinkState.disconnected => 'Tidak terhubung',
        FeederLinkState.unsupported => 'Tidak didukung',
        FeederLinkState.error => 'Gagal terhubung',
      };

  @override
  Widget build(BuildContext context) {
    final status = controller.status;
    final statusColor = switch (status) {
      FeederStatus.run => FutechiColors.success,
      FeederStatus.stop => FutechiColors.danger,
      FeederStatus.ready => FutechiColors.mutedForeground,
    };
    final conveyorSeconds = (controller.conveyorRemainingMs / 1000).ceil();
    return FutechiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Status Feeder',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: statusColor),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(status.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
            ],
          ),
          if (controller.feeding) ...[
            const SizedBox(height: 8),
            const Text('Menyiapkan pakan...',
                style: TextStyle(color: FutechiColors.warning)),
          ],
          const SizedBox(height: 12),
          _row('Mode', '${controller.runMode} Motor'),
          _row('Motor 1',
              _motorLabel(controller.motor1Running, controller.motor1Dir)),
          if (controller.runMode == 2)
            _row('Motor 2',
                _motorLabel(controller.motor2Running, controller.motor2Dir)),
          _row(
              'Conveyor',
              controller.conveyorRunning
                  ? 'Berjalan · $conveyorSeconds s'
                  : 'Berhenti (${controller.conveyorTime} s)'),
          const Divider(height: 24),
          _row('Feeder (MQTT)', _linkLabel(link.state)),
          _row('Status perangkat', controller.client2Status),
          if (link.state != FeederLinkState.connected && !link.isUnsupported) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('button_connect_hardware'),
                onPressed: link.isBusy ? null : () => link.connect(),
                icon: link.isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cable_outlined, size: 18),
                label: Text(link.isBusy
                    ? 'Menghubungkan...'
                    : 'Hubungkan ke Hardware'),
              ),
            ),
            if (link.state == FeederLinkState.error && link.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  link.lastError!,
                  style: const TextStyle(fontSize: 12, color: FutechiColors.danger),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: FutechiColors.mutedForeground)),
            ),
            Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
