import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'preview_theme.dart';

/// Cópia fiel de `widgets/cached_image.dart` do app Dellalio Clientes —
/// mesmo comportamento (assets vs. rede, fallback gracioso).
class PreviewCachedImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final Widget? fallback;
  final Color fallbackColor;

  const PreviewCachedImage({
    super.key,
    this.url,
    this.fit = BoxFit.cover,
    this.fallback,
    this.fallbackColor = AppColors.lightGray,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackWidget = fallback ?? ColoredBox(color: fallbackColor);

    if (url == null || url!.isEmpty) return fallbackWidget;

    if (url!.startsWith('assets/')) {
      // O app admin não empacota os assets do app cliente — mostra o
      // fallback até a foto real ser enviada pelo editor.
      return fallbackWidget;
    }

    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      placeholder: (_, _) => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
        ),
      ),
      errorWidget: (_, _, _) => fallbackWidget,
    );
  }
}
