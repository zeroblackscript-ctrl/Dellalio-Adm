import 'dart:async';
import 'package:flutter/material.dart';

import 'preview_cached_image.dart';
import 'preview_models.dart';
import 'preview_theme.dart';

/// Cópia de `widgets/project_spotlight_section.dart` do app Dellalio
/// Clientes, com `_current` protegido contra a lista de fotos encolher
/// enquanto o admin edita.
class PreviewSpotlightSection extends StatefulWidget {
  final SpotlightProject project;
  final bool isActive;

  const PreviewSpotlightSection({
    super.key,
    required this.project,
    required this.isActive,
  });

  @override
  State<PreviewSpotlightSection> createState() =>
      _PreviewSpotlightSectionState();
}

class _PreviewSpotlightSectionState extends State<PreviewSpotlightSection>
    with AutomaticKeepAliveClientMixin {
  int _current = 0;
  Timer? _timer;
  bool _wasActive = false;

  static const _cycleMs = 3000;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _wasActive = true;
      _startCycle();
    }
  }

  @override
  void didUpdateWidget(covariant PreviewSpotlightSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.project.photos.isEmpty) {
      _current = 0;
    } else if (_current >= widget.project.photos.length) {
      _current = widget.project.photos.length - 1;
    }
    if (widget.isActive && !_wasActive) {
      _current = 0;
      _startCycle();
    } else if (!widget.isActive && _wasActive) {
      _stopCycle();
      _current = 0;
    }
    _wasActive = widget.isActive;
  }

  @override
  void dispose() {
    _stopCycle();
    super.dispose();
  }

  void _startCycle() {
    _stopCycle();
    _timer = Timer.periodic(const Duration(milliseconds: _cycleMs), (_) {
      if (!mounted || !widget.isActive) return;
      if (widget.project.photos.isEmpty) return;
      setState(
        () => _current = (_current + 1) % widget.project.photos.length,
      );
    });
  }

  void _stopCycle() {
    _timer?.cancel();
    _timer = null;
  }

  List<SpotlightHighlight> _highlightsForCurrent() =>
      widget.project.highlights.where((h) => h.photoIndex == _current).toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final photos = widget.project.photos;
    final n = photos.length;
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (n == 0)
            const Center(
              child: Icon(Icons.image_outlined, color: Colors.white38, size: 48),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Stack(
                key: ValueKey(_current),
                fit: StackFit.expand,
                children: [
                  PreviewCachedImage(
                    url: photos[_current],
                    fit: BoxFit.cover,
                    fallbackColor: AppColors.navy,
                  ),
                  Container(color: Colors.black.withValues(alpha: 0.15)),
                  ..._highlightsForCurrent().map(_buildCallout),
                ],
              ),
            ),
          if (n > 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_current + 1} / $n',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          if (n > 0)
            Positioned(
              bottom: 130,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(n, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _current
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    );
                  }),
                ],
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'PROJETO EM DESTAQUE',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.project.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.project.tagline,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallout(SpotlightHighlight h) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Transform.translate(
            offset: h.alignmentOffset * 0.4,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) {
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - t)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            h.label,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            h.description,
                            style: const TextStyle(
                              color: AppColors.grayBlue,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
