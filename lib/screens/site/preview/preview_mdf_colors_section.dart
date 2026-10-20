import 'dart:async';
import 'package:flutter/material.dart';

import 'preview_models.dart';
import 'preview_theme.dart';

/// Cópia de `widgets/mdf_colors_section.dart` do app Dellalio Clientes.
class PreviewMdfColorsSection extends StatefulWidget {
  final bool isActive;
  final List<MdfColorSwatch> colors;

  const PreviewMdfColorsSection({
    super.key,
    required this.isActive,
    required this.colors,
  });

  @override
  State<PreviewMdfColorsSection> createState() =>
      _PreviewMdfColorsSectionState();
}

class _PreviewMdfColorsSectionState extends State<PreviewMdfColorsSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<Animation<double>> _fades;
  late List<Animation<Offset>> _slides;

  bool _wasActive = false;
  bool _showHint = false;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _buildStaggerAnimations();

    if (widget.isActive) {
      _wasActive = true;
      _showHint = true;
      _scheduleHintFade();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isActive) {
          _controller.forward(from: 0);
        }
      });
    }
  }

  void _buildStaggerAnimations() {
    final n = widget.colors.isEmpty ? 1 : widget.colors.length;
    _fades = [];
    _slides = [];
    for (var i = 0; i < n; i++) {
      final step = 1.0 / n;
      final start = (i * step * 0.7).clamp(0.0, 1.0);
      final end = (start + step).clamp(0.0, 1.0);
      final curve = Interval(start, end, curve: Curves.easeOutCubic);
      _fades.add(CurvedAnimation(parent: _controller, curve: curve));
      _slides.add(
        Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: curve)),
      );
    }
  }

  void _scheduleHintFade() {
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  @override
  void didUpdateWidget(covariant PreviewMdfColorsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.colors.length != oldWidget.colors.length) {
      _buildStaggerAnimations();
    }
    if (widget.isActive && !_wasActive) {
      _controller.forward(from: 0);
      _showHint = true;
      _scheduleHintFade();
    } else if (!widget.isActive && _wasActive) {
      _controller.reset();
      _hintTimer?.cancel();
      _showHint = false;
    }
    _wasActive = widget.isActive;
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildSwatch(int index) {
    final swatch = widget.colors[index];
    final dark =
        ThemeData.estimateBrightnessForColor(swatch.color) ==
        Brightness.dark;
    final textColor = dark ? Colors.white : AppColors.navy;
    return FadeTransition(
      opacity: _fades[index],
      child: SlideTransition(
        position: _slides[index],
        child: Container(
          decoration: BoxDecoration(
            color: swatch.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                swatch.name,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                swatch.finish,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.lightBg,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 28),
            Image.asset(
              'assets/imagens/logo/logo ld.png',
              height: 96,
              fit: BoxFit.contain,
              errorBuilder: (_, e, _) => const Icon(
                Icons.grid_view_rounded,
                size: 56,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'MDF PREMIUM',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'As cores que mais saem daqui',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: widget.colors.isEmpty
                  ? const SizedBox.shrink()
                  : GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: List.generate(
                        widget.colors.length,
                        _buildSwatch,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: _showHint ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: const Column(
                children: [
                  Icon(
                    Icons.keyboard_arrow_up,
                    color: AppColors.gold,
                    size: 28,
                  ),
                  Text(
                    'deslize',
                    style: TextStyle(color: AppColors.grayBlue, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
