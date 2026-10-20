import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:DELLALIO/screens/site/preview/preview_before_after_section.dart';
import 'package:DELLALIO/screens/site/preview/preview_categories_section.dart';
import 'package:DELLALIO/screens/site/preview/preview_mdf_colors_section.dart';
import 'package:DELLALIO/screens/site/preview/preview_models.dart';
import 'package:DELLALIO/screens/site/preview/preview_numbers_section.dart';
import 'package:DELLALIO/screens/site/preview/preview_slide_view.dart';
import 'package:DELLALIO/screens/site/preview/preview_slides_walkthrough.dart';
import 'package:DELLALIO/screens/site/preview/preview_spotlight_section.dart';
import 'package:DELLALIO/screens/site/preview/preview_testimonials_section.dart';

/// Renderiza [child] num viewport de exatamente 390×844 (o mesmo tamanho
/// lógico que PhoneFrame usa) e reporta qualquer overflow do RenderFlex.
Future<void> _pumpAtPhoneSize(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: SizedBox(width: 390, height: 844, child: child),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

const _categories = [
  RoomCategory(name: 'Cozinha', filterTag: 'cozinha'),
  RoomCategory(name: 'Quarto', filterTag: 'quarto'),
  RoomCategory(name: 'Closet', filterTag: 'closet'),
  RoomCategory(name: 'Sala', filterTag: 'sala'),
  RoomCategory(name: 'Home Office', filterTag: 'home-office'),
  RoomCategory(name: 'Banheiro', filterTag: 'banheiro'),
];

const _mdfColors = [
  MdfColorSwatch(name: 'Branco Polar', finish: 'Fosco', colorHex: 'F4F4F0'),
  MdfColorSwatch(name: 'Cinza Cristal', finish: 'Fosco', colorHex: '9E9E9E'),
  MdfColorSwatch(name: 'Carvalho', finish: 'Natural', colorHex: 'C39A6B'),
];

const _testimonials = [
  Testimonial(
    clientName: 'Mariana Lopes',
    city: 'São Paulo',
    rating: 5,
    quote:
        'Do projeto ao acabamento, tudo foi impecável. A cozinha ficou '
        'exatamente como sonhei — cada milímetro aproveitado.',
  ),
];

const _stats = [
  StatItem(value: 180, suffix: '+', label: 'projetos entregues'),
  StatItem(value: 2, suffix: '', label: 'anos de mercado'),
  StatItem(value: 98, suffix: '%', label: 'clientes satisfeitos'),
];

const _beforeAfter = BeforeAfterProject(
  beforeImageUrl: null,
  afterImageUrl: null,
);

const _spotlight = SpotlightProject(
  title: 'Lavanderia Colonial',
  tagline: 'Moldura clássica · ferragens douradas',
  photos: [],
  highlights: [],
);

final _slide = const ShowcaseSlide(
  id: 'materiais',
  background: SlideBackground.dark,
  eyebrow: 'MATERIAIS',
  title: 'Trabalhamos apenas com\nprodutos nobres',
  body:
      'Não trabalhamos com madeira — apenas MDF de alta densidade '
      'e ferragens Hardt, para o melhor resultado e qualidade.',
  animationType: SlideAnimationType.staggeredCards,
  materialItems: [
    MaterialItem(
      name: 'MDF de alta densidade',
      description:
          'Painéis com densidade acima de 700 kg/m³. Mais resistência, '
          'melhor acabamento e zero empenamento ao longo dos anos.',
    ),
    MaterialItem(
      name: 'Ferragens Hardt',
      description:
          'Corrediças, dobradiças e puxadores 100% Hardt. '
          'Precisão e durabilidade testadas para o uso diário '
          'sem folgas nem desgaste prematuro.',
    ),
  ],
);

void main() {
  final errors = <String>[];

  setUp(() {
    errors.clear();
    FlutterError.onError = (details) {
      errors.add(details.exceptionAsString());
    };
  });

  tearDown(() async {
    FlutterError.onError = FlutterError.presentError;
  });

  testWidgets('PreviewCategoriesSection', (tester) async {
    await _pumpAtPhoneSize(
      tester,
      const PreviewCategoriesSection(categories: _categories, isActive: true),
    );
    expect(errors, isEmpty, reason: errors.join('\n---\n'));
  });

  testWidgets('PreviewMdfColorsSection', (tester) async {
    await _pumpAtPhoneSize(
      tester,
      const PreviewMdfColorsSection(colors: _mdfColors, isActive: true),
    );
    expect(errors, isEmpty, reason: errors.join('\n---\n'));
  });

  testWidgets('PreviewTestimonialsSection', (tester) async {
    await _pumpAtPhoneSize(
      tester,
      const PreviewTestimonialsSection(items: _testimonials, isActive: true),
    );
    expect(errors, isEmpty, reason: errors.join('\n---\n'));
  });

  testWidgets('PreviewNumbersSection', (tester) async {
    await _pumpAtPhoneSize(
      tester,
      const PreviewNumbersSection(items: _stats, isActive: true),
    );
    expect(errors, isEmpty, reason: errors.join('\n---\n'));
  });

  testWidgets('PreviewBeforeAfterSection', (tester) async {
    await _pumpAtPhoneSize(
      tester,
      const PreviewBeforeAfterSection(project: _beforeAfter, isActive: true),
    );
    expect(errors, isEmpty, reason: errors.join('\n---\n'));
  });

  testWidgets('PreviewSpotlightSection (sem fotos)', (tester) async {
    await _pumpAtPhoneSize(
      tester,
      const PreviewSpotlightSection(project: _spotlight, isActive: true),
    );
    expect(errors, isEmpty, reason: errors.join('\n---\n'));
  });

  testWidgets('PreviewSlideView (staggeredCards)', (tester) async {
    await _pumpAtPhoneSize(
      tester,
      PreviewSlideView(slide: _slide, isActive: true),
    );
    expect(errors, isEmpty, reason: errors.join('\n---\n'));
  });

  testWidgets('PreviewSlidesWalkthrough', (tester) async {
    await _pumpAtPhoneSize(
      tester,
      PreviewSlidesWalkthrough(slides: [_slide]),
    );
    expect(errors, isEmpty, reason: errors.join('\n---\n'));
  });
}
