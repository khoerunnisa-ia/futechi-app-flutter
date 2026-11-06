import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/miniatur.dart';
import '../data/miniatur_link.dart';
import '../widgets/case_card.dart';
import '../widgets/page_title.dart';

/// Halaman Miniatur untuk pengguna awam.
///
/// Prinsip UI (disepakati dengan pemilik): hanya status koneksi, tombol
/// kontrol, dan keterangan yang bisa dibaca orang awam — tanpa istilah
/// teknis (MQTT, firmware, step, dsb). Seluruh logika tetap berada di
/// [MiniaturSimulator] (estimasi kondisi) dan [MiniaturLink] (kirim
/// perintah ke broker, siap dipakai begitu perangkat mendukung).
class MiniaturPage extends StatefulWidget {
  const MiniaturPage({super.key, this.controller, this.link});

  /// Defaults ke [MiniaturController.instance] / [sharedMiniaturLink].
  final MiniaturController? controller;
  final MiniaturLink? link;

  @override
  State<MiniaturPage> createState() => _MiniaturPageState();
}

class _MiniaturPageState extends State<MiniaturPage> {
  late final MiniaturController _controller =
      widget.controller ?? MiniaturController.instance;
  late final MiniaturLink _link = widget.link ?? sharedMiniaturLink;

  /// Jam repaint 2 Hz supaya progress/estimasi ikut berdetak.
  final ValueNotifier<int> _clock = ValueNotifier(0);
  Timer? _ticker;

  /// State lokal tombol lampu (perangkat belum menerima perintah nyata).
  bool _lamp1 = false;
  bool _lamp2 = false;

  double _volume = 0;

  @override
  void initState() {
    super.initState();
    _link.onMessage = _controller.handleMqttMessage;
    if (_link.state == MiniaturLinkState.disconnected) {
      _link.autoConnect();
    }
    _controller.simulator.loadTrack().whenComplete(() {
      if (mounted) setState(() {});
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _clock.value++;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clock.dispose();
    super.dispose();
  }

  MiniaturSimulator get _sim => _controller.simulator;

  // ============ pengaturan layar (kalibrasi) ============

  void _markNewPowerOn() {
    _sim.markPowerOn();
    _showSnack('Siap! Layar akan mengikuti miniatur.');
  }

  void _markArrivedAtStart() {
    _sim.markHomingFinished();
    _showSnack('Siap! Layar akan mengikuti miniatur.');
  }

  void _resetScreen() {
    _sim.resetCalibration();
  }

  // ============ tombol kontrol ============

  Future<void> _sendCommand(
    Map<String, Object?> command,
    String label,
  ) async {
    final ok = await _link.publishCommand(command);
    if (!mounted) return;
    if (ok) {
      _controller.log('$label → dikirim ke miniatur');
      _showSnack('"$label" dikirim ke miniatur');
    } else {
      _showSnack('Miniatur belum terhubung — perintah gagal dikirim');
    }
  }

  void _sendLamp(int lamp, bool on) {
    setState(() {
      if (lamp == 1) {
        _lamp1 = on;
      } else {
        _lamp2 = on;
      }
    });
    _sendCommand(MiniaturCommands.setLamp(lamp, on), 'Lampu ${lamp == 1 ? 1 : 2}');
  }

  void _changeLagu({required bool up}) {
    final before = _sim.track;
    if (up) {
      _sim.trackUp();
    } else {
      _sim.trackDown();
    }
    if (_sim.track == before) return;
    _controller.log('Lagu diubah ke $_sim.track');
    _showSnack('Lagu diatur ke "${_laguLabel(_sim.track)}"');
    _sendCommand(MiniaturCommands.setTrack(_sim.track), 'Ganti lagu');
  }

  String _laguLabel(int track) => 'Lagu $track dari 3';

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ============ tampilan ramah awam ============

  /// Kalimat kondisi per fase, tanpa istilah teknis.
  String _kondisiLabel(MiniaturSegment segment) => switch (segment) {
        MiniaturSegment.homing => 'Motor menuju posisi awal…',
        MiniaturSegment.standbyWait => 'Miniatur siap, menunggu mulai',
        MiniaturSegment.bothForward => 'Miniatur bergerak maju',
        MiniaturSegment.waitAfterBoth => 'Miniatur berhenti sebentar',
        MiniaturSegment.motor1Backward => 'Motor 1 kembali ke posisi awal',
        MiniaturSegment.waitAfterM1 => 'Miniatur berhenti sebentar',
        MiniaturSegment.motor2Backward => 'Motor 2 kembali ke posisi awal',
        MiniaturSegment.waitAfterM2 => 'Miniatur bersiap untuk putaran berikut',
      };

  (String, IconData, Color) _kondisiKoneksi() => switch (_link.state) {
        MiniaturLinkState.connected => (
            'Miniatur siap dikendalikan',
            Icons.wifi,
            FutechiColors.success,
          ),
        MiniaturLinkState.connecting => (
            'Menyambungkan…',
            Icons.sync,
            FutechiColors.warning,
          ),
        MiniaturLinkState.disconnected => (
            'Miniatur belum terhubung',
            Icons.wifi_off,
            FutechiColors.mutedForeground,
          ),
        MiniaturLinkState.error => (
            'Miniatur tidak terhubung',
            Icons.wifi_off,
            FutechiColors.danger,
          ),
        MiniaturLinkState.unsupported => (
            'Perangkat ini tidak mendukung pengendalian miniatur',
            Icons.wifi_off,
            FutechiColors.warning,
          ),
      };

  static String _detikLagi(int ms) {
    final detik = (ms / 1000).round();
    return detik <= 0 ? 'sebentar lagi' : '± $detik detik lagi';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _link, _clock]),
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          const PageTitle(
            title: 'Miniatur Futechi',
            description: 'Pantau kondisi miniatur dan kirim perintah.',
          ),
          const SizedBox(height: 16),
          _buildKoneksiBanner(context),
          const SizedBox(height: 16),
          _buildKondisiCard(context),
          const SizedBox(height: 16),
          _buildKontrolCard(context),
        ],
      ),
    );
  }

  Widget _buildKoneksiBanner(BuildContext context) {
    final (text, icon, color) = _kondisiKoneksi();
    final bisaSambung =
        _link.state == MiniaturLinkState.disconnected ||
            _link.state == MiniaturLinkState.error;
    return FutechiCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              key: const ValueKey('miniatur_status_label'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          if (bisaSambung)
            FilledButton(
              onPressed: _link.connect,
              child: const Text('Sambungkan'),
            ),
        ],
      ),
    );
  }

  Widget _buildKondisiCard(BuildContext context) {
    final sim = _sim;

    // Belum dikalibrasi sama sekali.
    if (!sim.hasPowerOn) {
      return _card(
        title: 'Kondisi Miniatur',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Layar ini siap mengikuti miniatur. Tancapkan miniatur '
              '(atau tekan tombol pengatur) lalu tekan tombol di bawah.',
              style: TextStyle(fontSize: 14, color: FutechiColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('miniatur_sync_power_on'),
                onPressed: _markNewPowerOn,
                icon: const Icon(Icons.power_settings_new),
                label: const Text('Ya, miniatur baru dinyalakan'),
              ),
            ),
          ],
        ),
      );
    }

    // Sudah menandai dinyalakan, menunggu konfirmasi motor berhenti.
    if (!sim.hasCycleBase) {
      return _card(
        title: 'Kondisi Miniatur',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Motor sedang mencari posisi awal. Setelah motor berhenti '
              'di posisi awal, tekan tombol di bawah.',
              style: TextStyle(fontSize: 14, color: FutechiColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('miniatur_sync_homing_done'),
                onPressed: _markArrivedAtStart,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Ya, sudah berhenti di posisi awal'),
              ),
            ),
            TextButton(
              onPressed: _resetScreen,
              child: const Text('Ulangi pengaturan layar'),
            ),
          ],
        ),
      );
    }

    // Kalibrasi penuh → tampilkan kondisi live.
    final s = sim.snapshotAt(DateTime.now());
    final berjalan = s.segmentDurationMs > 0;
    return _card(
      title: 'Kondisi Miniatur',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _kondisiLabel(s.segment),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: FutechiColors.foreground),
                ),
              ),
              if (s.cycleIndex > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: FutechiColors.secondarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('Putaran ke-${s.cycleIndex}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          if (berjalan) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: s.segmentProgress,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _detikLagi(s.segmentRemainingMs),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.music_note, size: 18,
                  color: FutechiColors.mutedForeground),
              const SizedBox(width: 8),
              Text(
                s.segment.isMotion
                    ? '${_laguLabel(_sim.track)} sedang berbunyi'
                    : 'Suara istirahat sedang berbunyi',
                style: const TextStyle(
                    fontSize: 14, color: FutechiColors.mutedForeground),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _markNewPowerOn,
                  icon: const Icon(Icons.power_settings_new, size: 18),
                  label: const Text('Miniatur baru dinyalakan',
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetScreen,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Atur ulang layar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Miniatur bekerja otomatis sesuai ritmenya sendiri — layar ini '
            'memperkirakan kondisinya dan bisa diikuti kapan pun.',
            style: TextStyle(fontSize: 12, color: FutechiColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _buildKontrolCard(BuildContext context) {
    return _card(
      title: 'Kontrol',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _tombolBesar(
                  label: 'Mulai',
                  icon: Icons.play_arrow,
                  onTap: () =>
                      _sendCommand(MiniaturCommands.cycleStart(), 'Mulai'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tombolBesar(
                  label: 'Jeda',
                  icon: Icons.pause,
                  onTap: () =>
                      _sendCommand(MiniaturCommands.cycleStop(), 'Jeda'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tombolBesar(
                  label: 'Kembali ke awal',
                  icon: Icons.settings_backup_restore,
                  onTap: () => _sendCommand(
                      MiniaturCommands.homeAll(), 'Kembali ke awal'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _grupLabel('Motor'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _tombolKecil('Motor 1 maju', Icons.arrow_upward,
                    () => _sendCommand(
                        MiniaturCommands.moveMotor(1, true), 'Motor 1 maju')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tombolKecil('Motor 1 mundur', Icons.arrow_downward,
                    () => _sendCommand(MiniaturCommands.moveMotor(1, false),
                        'Motor 1 mundur')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tombolKecil('Motor 2 maju', Icons.arrow_upward,
                    () => _sendCommand(
                        MiniaturCommands.moveMotor(2, true), 'Motor 2 maju')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tombolKecil('Motor 2 mundur', Icons.arrow_downward,
                    () => _sendCommand(MiniaturCommands.moveMotor(2, false),
                        'Motor 2 mundur')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _grupLabel('Volume suara'),
          Slider(
            value: _volume,
            max: 30,
            divisions: 30,
            label: _volume.round() < 8 ? 'Diam' : _volume.round().toString(),
            onChanged: (v) => setState(() => _volume = v),
            onChangeEnd: (v) => _sendCommand(
                MiniaturCommands.setVolume(v.round()),
                'Volume ${v.round()}'),
          ),
          const SizedBox(height: 8),
          _grupLabel('Lampu'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _sendLamp(1, !_lamp1),
                  icon: Icon(_lamp1 ? Icons.lightbulb : Icons.lightbulb_outline),
                  label: Text('Lampu 1 ${_lamp1 ? 'mati' : 'nyala'}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _sendLamp(2, !_lamp2),
                  icon: Icon(_lamp2 ? Icons.lightbulb : Icons.lightbulb_outline),
                  label: Text('Lampu 2 ${_lamp2 ? 'mati' : 'nyala'}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _grupLabel('Lagu'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _laguLabel(_sim.track),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _changeLagu(up: true),
                icon: const Icon(Icons.arrow_upward, size: 18),
                label: const Text('Maju'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _changeLagu(up: false),
                icon: const Icon(Icons.arrow_downward, size: 18),
                label: const Text('Mundur'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Ganti lagu juga bisa lewat tombol fisik di miniatur — cocokkan '
            'di sini bila berbeda.',
            style: TextStyle(fontSize: 12, color: FutechiColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return FutechiCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: FutechiColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _grupLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: FutechiColors.mutedForeground,
      ),
    );
  }

  Widget _tombolBesar({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _tombolKecil(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
