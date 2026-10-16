import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../app/theme.dart';
import '../config/env.dart';
import 'case_card.dart';

/// Widget CCTV Pemantauan Kandang — port dari bagian CCTV di DashboardPage
/// React (futechi-pages.tsx baris 322–350).
///
/// Menampilkan live RTSP stream kamera Tapo menggunakan `media_kit` (Opsi A).
/// Bila [Env.cctvRtspUrl] kosong, widget menampilkan thumbnail statis
/// `assets/images/cctv-kandang.jpg` sebagai mode demo.
///
/// Layout mengikuti React source:
/// - Header: judul "CCTV Pemantauan Kandang", subtitle "Kualitas HD",
///   badge merah "● LIVE".
/// - Frame: aspect-ratio 16:9, overlay play icon, tombol Expand di pojok
///   kanan atas, fallback thumbnail bila stream belum/tidak tersambung.
class CctvCard extends StatefulWidget {
  const CctvCard({super.key});

  @override
  State<CctvCard> createState() => _CctvCardState();
}

class _CctvCardState extends State<CctvCard> {
  late final Player _player;
  late final VideoController _controller;

  // Stream state
  _StreamState _streamState = _StreamState.idle;

  final String? _rtspUrl = Env.cctvRtspUrl;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
        title: 'CCTV Kandang',
        bufferSize: 1024 * 1024,
      ),
    );
    _controller = VideoController(_player);

    // Listen player stream errors
    _player.stream.error.listen((err) {
      if (mounted && err.isNotEmpty) {
        setState(() => _streamState = _StreamState.error);
        debugPrint('[CCTV] Error: $err');
      }
    });

    _player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      if (buffering && _streamState == _StreamState.playing) {
        setState(() => _streamState = _StreamState.buffering);
      }
    });

    _player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() =>
          _streamState = playing ? _StreamState.playing : _StreamState.idle);
    });

    if (Env.cctvAutoPlay && _rtspUrl != null && _rtspUrl.isNotEmpty) {
      _startStream();
    }
  }

  Future<void> _startStream() async {
    final url = _rtspUrl;
    if (url == null || url.isEmpty) return;
    setState(() => _streamState = _StreamState.connecting);
    try {
      await _player.open(
        Media(
          url,
          httpHeaders: const {
            'rtsp_transport': 'tcp',
          },
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _streamState = _StreamState.error);
      debugPrint('[CCTV] Gagal membuka stream: $e');
    }
  }

  Future<void> _stopStream() async {
    await _player.stop();
    if (mounted) setState(() => _streamState = _StreamState.idle);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutechiCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: judul + badge LIVE (React baris 323–331) ───
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CCTV Pemantauan Kandang',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kualitas HD',
                        style: TextStyle(
                          fontSize: 12,
                          color: FutechiColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FutechiColors.danger,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '● LIVE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Frame 16:9 (React baris 332–349) ───
          _buildVideoFrame(context),
        ],
      ),
    );
  }

  Widget _buildVideoFrame(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideoOrThumbnail(),
            _buildOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoOrThumbnail() {
    // Bila stream aktif, tampilkan video; selainnya fallback thumbnail
    if (_rtspUrl != null &&
        (_streamState == _StreamState.playing ||
            _streamState == _StreamState.buffering)) {
      return Video(controller: _controller);
    }

    // Thumbnail statis dari assets (fallback / mode demo)
    return Image.asset(
      'assets/images/cctv-kandang.jpg',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: FutechiColors.foreground,
        child: const Center(
          child: Icon(Icons.videocam_off_outlined,
              color: Colors.white54, size: 48),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return Container(
      color: FutechiColors.foreground.withAlpha(40),
      child: Stack(
        children: [
          // ─── Tombol Play / Connecting / Error di tengah ───
          Center(child: _buildCenterIndicator(context)),

          // ─── Tombol Expand di pojok kanan atas (React baris 341–348) ───
          Positioned(
            right: 12,
            top: 12,
            child: Material(
              color: FutechiColors.card.withAlpha(217),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showExpandedDialog(context),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.fullscreen, size: 20),
                ),
              ),
            ),
          ),

          // ─── Tombol Stop di pojok kiri atas (hanya saat streaming) ───
          if (_streamState == _StreamState.playing)
            Positioned(
              left: 12,
              top: 12,
              child: Material(
                color: FutechiColors.card.withAlpha(217),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _stopStream,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.stop_rounded, size: 20),
                  ),
                ),
              ),
            ),

          // ─── Status label bawah kiri (hanya saat streaming) ───
          if (_streamState == _StreamState.playing)
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(153),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '● Siaran Langsung',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCenterIndicator(BuildContext context) {
    switch (_streamState) {
      case _StreamState.connecting:
      case _StreamState.buffering:
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: FutechiColors.card.withAlpha(217),
            shape: BoxShape.circle,
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        );

      case _StreamState.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: FutechiColors.card.withAlpha(217),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: FutechiColors.danger, size: 28),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(153),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Kamera Tapo Offline\nKetuk untuk coba lagi',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _startStream,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reconnect', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8)),
            ),
          ],
        );

      case _StreamState.idle:
        // Tampilkan play button (seperti React: Video icon di tengah)
        if (_rtspUrl != null && _rtspUrl.isNotEmpty) {
          return GestureDetector(
            onTap: _startStream,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: FutechiColors.card.withAlpha(217),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_rounded,
                  color: FutechiColors.primary, size: 28),
            ),
          );
        }
        // Mode demo: tidak ada URL, tampilkan ikon video (seperti React)
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: FutechiColors.card.withAlpha(217),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.videocam_rounded,
              color: FutechiColors.primary, size: 28),
        );

      case _StreamState.playing:
        return const SizedBox.shrink();
    }
  }

  void _showExpandedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _streamState == _StreamState.playing ||
                        _streamState == _StreamState.buffering
                    ? Video(controller: _controller)
                    : Image.asset(
                        'assets/images/cctv-kandang.jpg',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.videocam_off_outlined,
                          color: Colors.white38,
                          size: 64,
                        ),
                      ),
              ),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.fullscreen_exit,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            if (_streamState == _StreamState.playing)
              const Positioned(
                left: 16,
                bottom: 16,
                child: Text(
                  '● CCTV Kandang — Siaran Langsung',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _StreamState { idle, connecting, buffering, playing, error }
