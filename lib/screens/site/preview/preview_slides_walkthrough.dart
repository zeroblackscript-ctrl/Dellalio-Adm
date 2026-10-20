import 'package:flutter/material.dart';

import 'preview_models.dart';
import 'preview_slide_view.dart';

/// Passeio navegável pelos slides (abertura/onboarding ou "Nosso trabalho")
/// — arraste ou toque nos pontinhos pra folhear, igual no app real.
class PreviewSlidesWalkthrough extends StatefulWidget {
  final List<ShowcaseSlide> slides;

  /// Se true, mostra a barra de topo com título e seta de voltar (estilo
  /// "Nosso trabalho"); se false, mostra o botão "Pular" (estilo onboarding).
  final bool withAppBar;

  const PreviewSlidesWalkthrough({
    super.key,
    required this.slides,
    this.withAppBar = false,
  });

  @override
  State<PreviewSlidesWalkthrough> createState() =>
      _PreviewSlidesWalkthroughState();
}

class _PreviewSlidesWalkthroughState extends State<PreviewSlidesWalkthrough> {
  final _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PreviewSlidesWalkthrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_current >= widget.slides.length) {
      _current = widget.slides.isEmpty ? 0 : widget.slides.length - 1;
    }
  }

  static const Color _gold = Color(0xFFC7AD85);

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF0D2B3E),
        child: Center(
          child: Text(
            'Nenhum slide cadastrado',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: widget.withAppBar
          ? AppBar(
              title: const Text('Nosso trabalho'),
              centerTitle: true,
              backgroundColor: const Color(0xFF0D2B3E),
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (ctx, i) => PreviewSlideView(
              slide: widget.slides[i],
              isActive: i == _current,
            ),
          ),
          if (!widget.withAppBar)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 20,
              child: const Text(
                'Pular',
                style: TextStyle(
                  color: _gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.slides.length, (i) {
                final active = i == _current;
                return GestureDetector(
                  onTap: () => _controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? _gold : _gold.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
