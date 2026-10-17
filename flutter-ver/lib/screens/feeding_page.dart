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

/// Status ringkas feeder di halaman Feeding.
enum FeederUiStatus { active, running, disconnected }

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

  void _stopFeeding() {
    _controller.stopAllMotor();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Feeding dihentikan')));
  }

  Future<void> _connect() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _link.connect();
    if (!ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(_link.lastError != null
            ? 'Gagal terhubung: ${_link.lastError}'
            : 'Gagal terhubung ke feeder'),
      ));
    }
  }

  FeederUiStatus get _uiStatus {
    if (_feedBusy) return FeederUiStatus.running;
    if (_link.state == FeederLinkState.connected) return FeederUiStatus.active;
    return FeederUiStatus.disconnected;
  }

  Widget _buildStatusRow(BuildContext context) {
    final status = _uiStatus;
    final (label, color) = switch (status) {
      FeederUiStatus.active => ('Aktif', FutechiColors.success),
      FeederUiStatus.running => ('Running', FutechiColors.warning),
      FeederUiStatus.disconnected => ('Disconnected', FutechiColors.danger),
    };
    final Widget action = switch (status) {
      FeederUiStatus.active => FilledButton.icon(
          key: const ValueKey('feeder_action_start'),
          onPressed: _feedNow,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Feeding'),
        ),
      FeederUiStatus.running => FilledButton.icon(
          key: const ValueKey('feeder_action_stop'),
          style: FilledButton.styleFrom(backgroundColor: FutechiColors.danger),
          onPressed: _controller.systemRunning ? _stopFeeding : null,
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
        ),
      FeederUiStatus.disconnected => OutlinedButton.icon(
          key: const ValueKey('feeder_action_connect'),
          onPressed: _link.isBusy || _link.isUnsupported ? null : _connect,
          icon: _link.isBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cable_outlined, size: 18),
          label: const Text('Connect'),
        ),
    };
    return FutechiCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              key: const ValueKey('feeder_status_label'),
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          action,
        ],
      ),
    );
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
        const PageTitle(
          title: 'Jadwal Pakan Otomatis',
          description: 'Atur sesi feeding Kandang',
        ),
        const SizedBox(height: 24),
        ListenableBuilder(
          listenable: Listenable.merge([_controller, _link]),
          builder: (context, _) => _buildStatusRow(context),
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
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(color: _items[i].enabled
                                    ? FutechiColors.foreground
                                    : FutechiColors.mutedForeground),
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
