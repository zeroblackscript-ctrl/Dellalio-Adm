import 'package:flutter/material.dart';

import 'preview_models.dart';
import 'preview_theme.dart';

/// Cópia de `widgets/testimonials_section.dart` do app Dellalio Clientes.
class PreviewTestimonialsSection extends StatefulWidget {
  final List<Testimonial> items;
  final bool isActive;

  const PreviewTestimonialsSection({
    super.key,
    required this.items,
    required this.isActive,
  });

  @override
  State<PreviewTestimonialsSection> createState() =>
      _PreviewTestimonialsSectionState();
}

class _PreviewTestimonialsSectionState
    extends State<PreviewTestimonialsSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  final PageController _pageController = PageController(
    viewportFraction: 0.85,
  );
  int _current = 0;
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curve);
    if (widget.isActive) {
      _wasActive = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isActive) _controller.forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(covariant PreviewTestimonialsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_wasActive) {
      _controller.forward(from: 0);
    } else if (!widget.isActive && _wasActive) {
      _controller.reset();
    }
    _wasActive = widget.isActive;
    if (_current >= widget.items.length) _current = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Widget _stars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star : Icons.star_border,
          size: 16,
          color: AppColors.gold,
        );
      }),
    );
  }

  Widget _card(Testimonial t) {
    final initial = t.clientName.isNotEmpty
        ? t.clientName[0].toUpperCase()
        : 'C';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.navy,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      t.city,
                      style: const TextStyle(
                        color: AppColors.grayBlue,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _stars(t.rating),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              t.quote,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.lightBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'QUEM JÁ CONFIOU',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'O que nossos clientes dizem',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: widget.items.isEmpty
                    ? const SizedBox.shrink()
                    : FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (i) => setState(() => _current = i),
                            itemCount: widget.items.length,
                            itemBuilder: (ctx, i) => _card(widget.items[i]),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.items.length, (i) {
                  final active = i == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 16 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.gold
                          : AppColors.gold.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
