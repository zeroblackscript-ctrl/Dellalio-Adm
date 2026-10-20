import 'package:flutter/material.dart';

import 'preview_cached_image.dart';
import 'preview_models.dart';

/// Cópia de `widgets/showcase_slide_view.dart` do app Dellalio Clientes.
class PreviewSlideView extends StatefulWidget {
  final ShowcaseSlide slide;
  final bool isActive;

  const PreviewSlideView({
    super.key,
    required this.slide,
    required this.isActive,
  });

  @override
  State<PreviewSlideView> createState() => _PreviewSlideViewState();
}

class _PreviewSlideViewState extends State<PreviewSlideView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _wasActive = false;

  late Animation<double> _fadeLogo;
  late Animation<double> _fadeTitle;
  late Animation<Offset> _slideTitle;

  late Animation<double> _photoScaleZoom;
  late Animation<double> _textFadeZoom;
  late Animation<Offset> _textSlideZoom;

  late Animation<double> _cropScale;
  late Animation<double> _ctaPulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeLogo = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _fadeTitle = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
      ),
    );
    _slideTitle = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
          ),
        );

    _photoScaleZoom = Tween<double>(begin: 1.1, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _textFadeZoom = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.7, curve: Curves.easeOut),
      ),
    );
    _textSlideZoom = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.15, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _cropScale = Tween<double>(begin: 1.15, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _ctaPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    if (widget.isActive) {
      _controller.forward(from: 0);
      _wasActive = true;
    }
  }

  @override
  void didUpdateWidget(covariant PreviewSlideView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_wasActive) {
      _controller.forward(from: 0);
    } else if (!widget.isActive && _wasActive) {
      _controller.reset();
    }
    _wasActive = widget.isActive;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color bgColor(SlideBackground bg) {
    switch (bg) {
      case SlideBackground.dark:
        return const Color(0xFF0D2B3E);
      case SlideBackground.light:
        return const Color(0xFFF7F3EC);
    }
  }

  Color textColor(SlideBackground bg) =>
      bg == SlideBackground.dark ? Colors.white : const Color(0xFF0D2B3E);

  Color bodyColor(SlideBackground bg) => bg == SlideBackground.dark
      ? const Color(0xFFC7AD85).withValues(alpha: 0.9)
      : const Color(0xFF0D2B3E).withValues(alpha: 0.75);

  static const Color gold = Color(0xFFC7AD85);

  Widget buildEyebrow() {
    if (widget.slide.eyebrow == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        widget.slide.eyebrow!,
        style: const TextStyle(
          color: gold,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.5,
        ),
      ),
    );
  }

  Widget buildBadge() {
    if (widget.slide.badge == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.35)),
      ),
      child: Text(
        widget.slide.badge!,
        style: const TextStyle(
          color: gold,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget buildTitle(SlideBackground bg) => Text(
    widget.slide.title,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: textColor(bg),
      fontSize: 26,
      fontWeight: FontWeight.w500,
      height: 1.3,
    ),
  );

  Widget buildBody(SlideBackground bg) {
    if (widget.slide.body == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        widget.slide.body!,
        textAlign: TextAlign.center,
        style: TextStyle(color: bodyColor(bg), fontSize: 14, height: 1.55),
      ),
    );
  }

  Widget buildCta() {
    if (widget.slide.ctaLabel == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: AnimatedBuilder(
        animation: _ctaPulse,
        builder: (_, child) =>
            Transform.scale(scale: _ctaPulse.value, child: child),
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: Colors.white,
            disabledBackgroundColor: gold,
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 0,
          ),
          child: Text(
            widget.slide.ctaLabel!,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildImageBackground() {
    return PreviewCachedImage(
      url: widget.slide.imagePath,
      fit: BoxFit.cover,
      fallback: Container(color: gold.withValues(alpha: 0.25)),
    );
  }

  Widget buildBodyPhoto() {
    if (widget.slide.body == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        widget.slide.body!,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 14,
          height: 1.55,
        ),
      ),
    );
  }

  Widget buildFadeUpLayout() {
    final bg = widget.slide.background;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(
          opacity: _fadeLogo,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: SizedBox(
              height: 120,
              child: widget.slide.imagePath != null
                  ? PreviewCachedImage(
                      url: widget.slide.imagePath,
                      fit: BoxFit.contain,
                      fallback: const Icon(
                        Icons.grid_view_rounded,
                        size: 44,
                        color: gold,
                      ),
                    )
                  : const Icon(Icons.grid_view_rounded, size: 44, color: gold),
            ),
          ),
        ),
        const SizedBox(height: 28),
        FadeTransition(
          opacity: _fadeTitle,
          child: SlideTransition(
            position: _slideTitle,
            child: Column(children: [buildEyebrow(), buildTitle(bg)]),
          ),
        ),
      ],
    );
  }

  Widget buildZoomOutPhotoLayout() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _photoScaleZoom,
            builder: (_, child) =>
                Transform.scale(scale: _photoScaleZoom.value, child: child),
            child: buildImageBackground(),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0D2B3E).withValues(alpha: 0.15),
                    const Color(0xFF0D2B3E).withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 48,
          child: FadeTransition(
            opacity: _textFadeZoom,
            child: SlideTransition(
              position: _textSlideZoom,
              child: Column(
                children: [
                  buildBadge(),
                  const SizedBox(height: 8),
                  Text(
                    widget.slide.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  buildBodyPhoto(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildStaggeredCardsLayout() {
    final bg = widget.slide.background;
    final items = widget.slide.materialItems;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildEyebrow(),
        const SizedBox(height: 4),
        buildTitle(bg),
        buildBody(bg),
        const SizedBox(height: 28),
        ...List.generate(items.length, (i) {
          final start = (i * 0.11).clamp(0.0, 1.0);
          final end = (start + 0.25).clamp(0.0, 1.0);
          final interval = Interval(start, end, curve: Curves.easeOutCubic);
          return AnimatedBuilder(
            animation: _controller,
            builder: (_, child) {
              final t = interval.transform(_controller.value);
              final o = (t / (end - start)).clamp(0.0, 1.0);
              return Opacity(
                opacity: o,
                child: Transform.translate(
                  offset: Offset(0.3 * (1 - t), 0),
                  child: child,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withValues(alpha: 0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, color: gold, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget buildCropInPhotoLayout() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _cropScale,
            builder: (_, child) =>
                Transform.scale(scale: _cropScale.value, child: child),
            child: buildImageBackground(),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0D2B3E).withValues(alpha: 0.15),
                    const Color(0xFF0D2B3E).withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 48,
          child: Column(
            children: [
              buildBadge(),
              const SizedBox(height: 8),
              Text(
                widget.slide.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
              buildBodyPhoto(),
              buildCta(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.slide.background;
    Widget content;
    switch (widget.slide.animationType) {
      case SlideAnimationType.fadeUp:
        content = buildFadeUpLayout();
      case SlideAnimationType.zoomOutPhoto:
        content = buildZoomOutPhotoLayout();
      case SlideAnimationType.staggeredCards:
        content = buildStaggeredCardsLayout();
      case SlideAnimationType.cropInPhoto:
        content = buildCropInPhotoLayout();
    }
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: bgColor(bg),
      child: SafeArea(child: content),
    );
  }
}
