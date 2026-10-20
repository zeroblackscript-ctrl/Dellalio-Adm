import 'package:flutter/material.dart';

import 'preview_cached_image.dart';
import 'preview_models.dart';
import 'preview_theme.dart';

/// Cópia de `widgets/categories_section.dart` do app Dellalio Clientes,
/// adaptada pro preview ao vivo do painel (sem navegação; robusta a mudar
/// de tamanho a lista enquanto o admin edita).
class PreviewCategoriesSection extends StatefulWidget {
  final List<RoomCategory> categories;
  final bool isActive;

  const PreviewCategoriesSection({
    super.key,
    required this.categories,
    required this.isActive,
  });

  @override
  State<PreviewCategoriesSection> createState() =>
      _PreviewCategoriesSectionState();
}

class _PreviewCategoriesSectionState extends State<PreviewCategoriesSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<Animation<double>> _fades;
  late List<Animation<double>> _scales;
  bool _wasActive = false;

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isActive) _controller.forward(from: 0);
      });
    }
  }

  void _buildStaggerAnimations() {
    final n = widget.categories.isEmpty ? 1 : widget.categories.length;
    final pairs = (n / 2).ceil();
    _fades = [];
    _scales = [];
    for (var i = 0; i < n; i++) {
      final pair = i ~/ 2;
      final start = (pair / pairs * 0.6).clamp(0.0, 1.0);
      final end = (start + 0.35).clamp(0.0, 1.0);
      final curve = Interval(start, end, curve: Curves.easeOutCubic);
      _fades.add(CurvedAnimation(parent: _controller, curve: curve));
      _scales.add(
        Tween<double>(
          begin: 0.92,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _controller, curve: curve)),
      );
    }
  }

  @override
  void didUpdateWidget(covariant PreviewCategoriesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories.length != oldWidget.categories.length) {
      _buildStaggerAnimations();
    }
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

  Widget _fallback(int i) {
    final palettes = [
      [AppColors.navy, const Color(0xFF24455E)],
      [const Color(0xFF24455E), AppColors.navy],
      [AppColors.gold, const Color(0xFF8E7249)],
    ];
    final c = palettes[i % palettes.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c,
        ),
      ),
    );
  }

  Widget _tile(int i) {
    final cat = widget.categories[i];
    return FadeTransition(
      opacity: _fades[i],
      child: ScaleTransition(
        scale: _scales[i],
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PreviewCachedImage(
                url: cat.imageUrl,
                fit: BoxFit.cover,
                fallback: _fallback(i),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(
                  cat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
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
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'EXPLORE POR AMBIENTE',
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
                  'Qual espaço você quer transformar?',
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
                child: widget.categories.isEmpty
                    ? const SizedBox.shrink()
                    : GridView.count(
                        crossAxisCount: 2,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: List.generate(
                          widget.categories.length,
                          _tile,
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Ver todos os projetos',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
