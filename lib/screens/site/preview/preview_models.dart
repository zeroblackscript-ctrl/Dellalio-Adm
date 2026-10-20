// Cópia dos models do app Dellalio Clientes usada só pelo preview "celular"
// do painel App Clientes — mesma forma dos documentos gravados em
// `site_content` no Firestore.
import 'package:flutter/material.dart';

class Testimonial {
  final String clientName;
  final String city;
  final int rating;
  final String quote;
  final String? photoUrl;

  const Testimonial({
    required this.clientName,
    required this.city,
    required this.rating,
    required this.quote,
    this.photoUrl,
  });

  factory Testimonial.fromMap(Map<String, dynamic> map) => Testimonial(
    clientName: map['clientName'] as String? ?? '',
    city: map['city'] as String? ?? '',
    rating: (map['rating'] as num?)?.toInt() ?? 5,
    quote: map['quote'] as String? ?? '',
    photoUrl: map['photoUrl'] as String?,
  );
}

class RoomCategory {
  final String name;
  final String? imageUrl;
  final String filterTag;

  const RoomCategory({
    required this.name,
    this.imageUrl,
    required this.filterTag,
  });

  factory RoomCategory.fromMap(Map<String, dynamic> map) => RoomCategory(
    name: map['name'] as String? ?? '',
    imageUrl: map['imageUrl'] as String?,
    filterTag: map['filterTag'] as String? ?? '',
  );
}

class MdfColorSwatch {
  final String name;
  final String finish;
  final String colorHex;

  const MdfColorSwatch({
    required this.name,
    required this.finish,
    required this.colorHex,
  });

  Color get color {
    final hex = colorHex.replaceAll('#', '');
    final value = int.tryParse(hex, radix: 16) ?? 0xFFFFFF;
    return Color(0xFF000000 | value);
  }

  factory MdfColorSwatch.fromMap(Map<String, dynamic> map) => MdfColorSwatch(
    name: map['name'] as String? ?? '',
    finish: map['finish'] as String? ?? '',
    colorHex: map['colorHex'] as String? ?? 'FFFFFF',
  );
}

class StatItem {
  final int value;
  final String suffix;
  final String label;

  const StatItem({
    required this.value,
    required this.suffix,
    required this.label,
  });

  factory StatItem.fromMap(Map<String, dynamic> map) => StatItem(
    value: (map['value'] as num?)?.toInt() ?? 0,
    suffix: map['suffix'] as String? ?? '',
    label: map['label'] as String? ?? '',
  );
}

class BeforeAfterProject {
  final String? beforeImageUrl;
  final String? afterImageUrl;

  const BeforeAfterProject({this.beforeImageUrl, this.afterImageUrl});
}

class ShowcaseVideo {
  final String videoUrl;
  final String title;
  final String subtitle;

  const ShowcaseVideo({
    required this.videoUrl,
    required this.title,
    required this.subtitle,
  });
}

enum SpotlightPosition { topLeft, topRight, center, bottomLeft, bottomRight }

class SpotlightHighlight {
  final String label;
  final String description;
  final int photoIndex;
  final SpotlightPosition position;

  const SpotlightHighlight({
    required this.label,
    required this.description,
    required this.photoIndex,
    required this.position,
  });

  Offset get alignmentOffset {
    switch (position) {
      case SpotlightPosition.topLeft:
        return const Offset(-0.85, -0.7);
      case SpotlightPosition.topRight:
        return const Offset(0.85, -0.7);
      case SpotlightPosition.center:
        return const Offset(0, 0.15);
      case SpotlightPosition.bottomLeft:
        return const Offset(-0.85, 0.55);
      case SpotlightPosition.bottomRight:
        return const Offset(0.85, 0.55);
    }
  }

  static SpotlightPosition _positionFromString(String? s) {
    switch (s) {
      case 'topLeft':
        return SpotlightPosition.topLeft;
      case 'topRight':
        return SpotlightPosition.topRight;
      case 'bottomLeft':
        return SpotlightPosition.bottomLeft;
      case 'bottomRight':
        return SpotlightPosition.bottomRight;
      default:
        return SpotlightPosition.center;
    }
  }

  factory SpotlightHighlight.fromMap(Map<String, dynamic> map) =>
      SpotlightHighlight(
        label: map['label'] as String? ?? '',
        description: map['description'] as String? ?? '',
        photoIndex: (map['photoIndex'] as num?)?.toInt() ?? 0,
        position: _positionFromString(map['position'] as String?),
      );
}

class SpotlightProject {
  final String title;
  final String tagline;
  final List<String> photos;
  final List<SpotlightHighlight> highlights;

  const SpotlightProject({
    required this.title,
    required this.tagline,
    required this.photos,
    required this.highlights,
  });
}

enum SlideBackground { dark, light }

enum SlideAnimationType { fadeUp, zoomOutPhoto, staggeredCards, cropInPhoto }

class MaterialItem {
  final String name;
  final String description;

  const MaterialItem({required this.name, required this.description});

  factory MaterialItem.fromMap(Map<String, dynamic> map) => MaterialItem(
    name: map['name'] as String? ?? '',
    description: map['description'] as String? ?? '',
  );
}

class ShowcaseSlide {
  final String id;
  final SlideBackground background;
  final String? eyebrow;
  final String title;
  final String? body;
  final String? imagePath;
  final SlideAnimationType animationType;
  final String? ctaLabel;
  final String? badge;
  final List<MaterialItem> materialItems;

  const ShowcaseSlide({
    required this.id,
    required this.background,
    this.eyebrow,
    required this.title,
    this.body,
    this.imagePath,
    required this.animationType,
    this.ctaLabel,
    this.badge,
    this.materialItems = const [],
  });

  static SlideBackground _backgroundFromString(String? s) =>
      s == 'light' ? SlideBackground.light : SlideBackground.dark;

  static SlideAnimationType _animationFromString(String? s) {
    switch (s) {
      case 'zoomOutPhoto':
        return SlideAnimationType.zoomOutPhoto;
      case 'staggeredCards':
        return SlideAnimationType.staggeredCards;
      case 'cropInPhoto':
        return SlideAnimationType.cropInPhoto;
      default:
        return SlideAnimationType.fadeUp;
    }
  }

  factory ShowcaseSlide.fromMap(Map<String, dynamic> map) {
    final materialItems =
        (map['materialItems'] as List?)
            ?.map((e) => MaterialItem.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const <MaterialItem>[];
    return ShowcaseSlide(
      id: map['id'] as String? ?? '',
      background: _backgroundFromString(map['background'] as String?),
      eyebrow: map['eyebrow'] as String?,
      title: map['title'] as String? ?? '',
      body: map['body'] as String?,
      imagePath: map['imagePath'] as String?,
      animationType: _animationFromString(map['animationType'] as String?),
      ctaLabel: map['ctaLabel'] as String?,
      badge: map['badge'] as String?,
      materialItems: materialItems,
    );
  }
}
