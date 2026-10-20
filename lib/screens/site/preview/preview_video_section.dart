import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'preview_models.dart';
import 'preview_theme.dart';

/// Cópia de `widgets/project_video_section.dart` do app Dellalio Clientes.
/// O admin não empacota vídeos locais do app cliente, então URLs `assets/`
/// mostram o estado "vídeo indisponível" até uma URL real ser enviada.
class PreviewVideoSection extends StatefulWidget {
  final ShowcaseVideo video;
  final bool isActive;

  const PreviewVideoSection({
    super.key,
    required this.video,
    required this.isActive,
  });

  @override
  State<PreviewVideoSection> createState() => _PreviewVideoSectionState();
}

class _PreviewVideoSectionState extends State<PreviewVideoSection> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;
  bool _muted = true;
  String? _loadedUrl;

  @override
  void initState() {
    super.initState();
    _init(widget.video.videoUrl);
  }

  @override
  void didUpdateWidget(covariant PreviewVideoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.video.videoUrl != _loadedUrl) {
      _init(widget.video.videoUrl);
    }
  }

  Future<void> _init(String url) async {
    _loadedUrl = url;
    await _controller?.dispose();
    _controller = null;
    if (url.isEmpty || url.startsWith('assets/')) {
      setState(() {
        _initialized = false;
        _error = true;
      });
      return;
    }
    setState(() {
      _initialized = false;
      _error = false;
    });
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted) return;
      setState(() => _initialized = true);
      controller.play();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _controller?.setVolume(_muted ? 0 : 1);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildVideoLayer() {
    if (_error) {
      return Container(
        color: AppColors.navy,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_outlined, color: AppColors.gold, size: 48),
              SizedBox(height: 12),
              Text(
                'Vídeo indisponível',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  Widget _buildMuteButton() {
    if (_controller == null || !_initialized) return const SizedBox.shrink();
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _toggleMute,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            _muted ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildTextOverlay() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PROJETO ENTREGUE',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.video.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.video.subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoLayer(),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 28, right: 16),
                child: _buildMuteButton(),
              ),
            ),
          ),
          _buildTextOverlay(),
        ],
      ),
    );
  }
}
