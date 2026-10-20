import 'package:flutter/material.dart';

import 'preview_cached_image.dart';
import 'preview_models.dart';
import 'preview_theme.dart';

/// Cópia de `widgets/before_after_section.dart` do app Dellalio Clientes.
class PreviewBeforeAfterSection extends StatefulWidget {
  final BeforeAfterProject project;
  final bool isActive;

  const PreviewBeforeAfterSection({
    super.key,
    required this.project,
    required this.isActive,
  });

  @override
  State<PreviewBeforeAfterSection> createState() =>
      _PreviewBeforeAfterSectionState();
}

class _PreviewBeforeAfterSectionState extends State<PreviewBeforeAfterSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _auto;
  double _slider = 0.5;
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _auto = Tween<double>(
      begin: 1.0,
      end: 0.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));
    _auto.addListener(() {
      if (mounted) setState(() => _slider = _auto.value);
    });
    if (widget.isActive) {
      _wasActive = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isActive) _controller.forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(covariant PreviewBeforeAfterSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_wasActive) {
      _controller.forward(from: 0);
    } else if (!widget.isActive && _wasActive) {
      _controller.stop();
      _slider = 0.5;
    }
    _wasActive = widget.isActive;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _badge(String text, {required bool dark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? AppColors.navy : AppColors.lightBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: dark ? Colors.white : AppColors.navy,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _placeholder(String label, {bool dark = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [AppColors.navy, const Color(0xFF24455E)]
              : [const Color(0xFFE8E4DC), const Color(0xFFD8D2C8)],
        ),
      ),
      child: Center(
        child: Icon(
          dark ? Icons.weekend : Icons.construction,
          size: 48,
          color: dark ? AppColors.gold : AppColors.grayBlue,
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
                  'TRANSFORMACAO',
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
                  'O antes nao conta a historia toda',
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
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final w = constraints.maxWidth;
                    final leftW = (w * _slider).clamp(0.0, w);
                    final rightW = w - leftW;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: GestureDetector(
                        onHorizontalDragUpdate: (d) {
                          _controller.stop();
                          setState(() {
                            _slider = (_slider + d.delta.dx / w).clamp(
                              0.0,
                              1.0,
                            );
                          });
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: leftW,
                                  child: ClipRect(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: 1,
                                      child: PreviewCachedImage(
                                        url: widget.project.beforeImageUrl,
                                        fit: BoxFit.cover,
                                        fallback: _placeholder('antes'),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: rightW,
                                  child: ClipRect(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      widthFactor: 1,
                                      child: PreviewCachedImage(
                                        url: widget.project.afterImageUrl,
                                        fit: BoxFit.cover,
                                        fallback: _placeholder(
                                          'depois',
                                          dark: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (leftW > 0)
                              Positioned(
                                left: leftW - 1.5,
                                top: 0,
                                bottom: 0,
                                child: const SizedBox(
                                  width: 3,
                                  child: ColoredBox(color: Colors.white),
                                ),
                              ),
                            Positioned(
                              left: leftW - 22,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: AppColors.gold,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.compare_arrows,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              left: 12,
                              child: _badge('ANTES', dark: false),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: _badge('DEPOIS', dark: true),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Arraste para comparar',
                  style: TextStyle(color: AppColors.grayBlue, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
