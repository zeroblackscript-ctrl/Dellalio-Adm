import 'package:flutter/material.dart';

import 'preview_models.dart';
import 'preview_theme.dart';

/// Cópia de `widgets/numbers_section.dart` do app Dellalio Clientes.
class PreviewNumbersSection extends StatefulWidget {
  final List<StatItem> items;
  final bool isActive;

  const PreviewNumbersSection({
    super.key,
    required this.items,
    required this.isActive,
  });

  @override
  State<PreviewNumbersSection> createState() => _PreviewNumbersSectionState();
}

class _PreviewNumbersSectionState extends State<PreviewNumbersSection> {
  @override
  void didUpdateWidget(covariant PreviewNumbersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) setState(() {});
  }

  Widget _count(int value, String suffix, TextStyle style, int durationMs) {
    if (!widget.isActive) {
      return Text('0$suffix', style: style);
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
      builder: (ctx, count, _) => Text('$count$suffix', style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    final big = widget.items.isNotEmpty
        ? widget.items.first
        : const StatItem(value: 0, suffix: '', label: '');
    final others = widget.items.length > 1
        ? widget.items.sublist(1)
        : const <StatItem>[];

    return Container(
      color: AppColors.navy,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 28),
              const Text(
                'DELLALIO EM NÚMEROS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Não é sorte, é processo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _count(
                big.value,
                big.suffix,
                const TextStyle(
                  color: AppColors.gold,
                  fontSize: 80,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
                1600,
              ),
              const SizedBox(height: 8),
              Text(
                big.label,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  for (final s in others)
                    Expanded(
                      child: Column(
                        children: [
                          _count(
                            s.value,
                            s.suffix,
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                            ),
                            1200,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const Spacer(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
