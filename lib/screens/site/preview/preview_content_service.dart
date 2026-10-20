import 'package:cloud_firestore/cloud_firestore.dart';

import 'preview_models.dart';

/// Lê ao vivo a coleção `site_content` (mesma do app cliente) pra alimentar
/// o celular sempre visível do hub "App Clientes" — com fallback pro
/// mesmo conteúdo padrão que os botões "Carregar dados atuais do app" usam,
/// então o celular nunca aparece vazio.
class PreviewContentService {
  final _collection = FirebaseFirestore.instance.collection('site_content');

  Stream<List<RoomCategory>> categories() {
    return _collection.doc('categories').snapshots().map((doc) {
      final items = doc.data()?['items'] as List?;
      if (items == null || items.isEmpty) return _defaultCategories;
      return items.map((e) => RoomCategory.fromMap(e)).toList();
    });
  }

  Stream<List<MdfColorSwatch>> mdfColors() {
    return _collection.doc('mdf_colors').snapshots().map((doc) {
      final items = doc.data()?['items'] as List?;
      if (items == null || items.isEmpty) return _defaultMdfColors;
      return items.map((e) => MdfColorSwatch.fromMap(e)).toList();
    });
  }

  Stream<List<Testimonial>> testimonials() {
    return _collection.doc('testimonials').snapshots().map((doc) {
      final items = doc.data()?['items'] as List?;
      if (items == null || items.isEmpty) return _defaultTestimonials;
      return items.map((e) => Testimonial.fromMap(e)).toList();
    });
  }

  Stream<List<StatItem>> stats() {
    return _collection.doc('stats').snapshots().map((doc) {
      final items = doc.data()?['items'] as List?;
      if (items == null || items.isEmpty) return _defaultStats;
      return items.map((e) => StatItem.fromMap(e)).toList();
    });
  }

  Stream<BeforeAfterProject> beforeAfter() {
    return _collection.doc('before_after').snapshots().map((doc) {
      final items = doc.data()?['items'] as List?;
      if (items == null || items.isEmpty) return _defaultBeforeAfter;
      return BeforeAfterProject(
        beforeImageUrl: items.first['beforeImageUrl'] as String?,
        afterImageUrl: items.first['afterImageUrl'] as String?,
      );
    });
  }

  Stream<ShowcaseVideo> showcaseVideo() {
    return _collection.doc('showcase_video').snapshots().map((doc) {
      final data = doc.data();
      if (data == null || data.isEmpty) return _defaultVideo;
      return ShowcaseVideo(
        videoUrl: data['videoUrl'] as String? ?? '',
        title: data['title'] as String? ?? '',
        subtitle: data['subtitle'] as String? ?? '',
      );
    });
  }

  Stream<SpotlightProject> spotlightProject() {
    return _collection.doc('spotlight_project').snapshots().map((doc) {
      final data = doc.data();
      if (data == null || data.isEmpty) return _defaultSpotlight;
      final highlights = (data['highlights'] as List?)
              ?.map((e) => SpotlightHighlight.fromMap(e))
              .toList() ??
          const <SpotlightHighlight>[];
      final photos =
          (data['photos'] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[];
      return SpotlightProject(
        title: data['title'] as String? ?? '',
        tagline: data['tagline'] as String? ?? '',
        photos: photos,
        highlights: highlights,
      );
    });
  }

  Stream<List<ShowcaseSlide>> showcaseSlides() {
    return _collection.doc('showcase_slides').snapshots().map((doc) {
      final items = doc.data()?['items'] as List?;
      if (items == null || items.isEmpty) return _defaultSlides;
      return items.map((e) => ShowcaseSlide.fromMap(e)).toList();
    });
  }
}

// ── Mesmo conteúdo padrão dos botões "Carregar dados atuais do app" ──────

const List<RoomCategory> _defaultCategories = [
  RoomCategory(name: 'Cozinha', filterTag: 'cozinha'),
  RoomCategory(name: 'Quarto', filterTag: 'quarto'),
  RoomCategory(name: 'Closet', filterTag: 'closet'),
  RoomCategory(name: 'Sala', filterTag: 'sala'),
  RoomCategory(name: 'Home Office', filterTag: 'home-office'),
  RoomCategory(name: 'Banheiro', filterTag: 'banheiro'),
];

const List<MdfColorSwatch> _defaultMdfColors = [
  MdfColorSwatch(name: 'Branco Polar', finish: 'Fosco', colorHex: 'F4F4F0'),
  MdfColorSwatch(name: 'Cinza Cristal', finish: 'Fosco', colorHex: '9E9E9E'),
  MdfColorSwatch(name: 'Carvalho', finish: 'Natural', colorHex: 'C39A6B'),
  MdfColorSwatch(name: 'Nogueira', finish: 'Natural', colorHex: '6B4A2F'),
  MdfColorSwatch(name: 'Preto Fosco', finish: 'Fosco', colorHex: '2B2B2B'),
  MdfColorSwatch(name: 'Freijó', finish: 'Natural', colorHex: 'D9B98C'),
];

const List<Testimonial> _defaultTestimonials = [
  Testimonial(
    clientName: 'Mariana Lopes',
    city: 'São Paulo',
    rating: 5,
    quote:
        'Do projeto ao acabamento, tudo foi impecável. A cozinha ficou '
        'exatamente como sonhei — cada milímetro aproveitado.',
  ),
  Testimonial(
    clientName: 'Rafael Moura',
    city: 'Campinas',
    rating: 5,
    quote:
        'Acompanhei cada etapa pelo app. Quando chegaram pra montar, '
        'foi rápido, limpo e sem nenhuma surpresa.',
  ),
  Testimonial(
    clientName: 'Camila e Bruno',
    city: 'Jundiaí',
    rating: 4,
    quote:
        'O closet ficou perfeito. O único adiamento foi por causa da '
        'nossa obra, e mesmo assim entregaram no remanejado.',
  ),
  Testimonial(
    clientName: 'Fernanda Reis',
    city: 'Santos',
    rating: 5,
    quote:
        'Ferragem de verdade, acabamento impecável. Dá pra sentir a '
        'qualidade no toque. Recomendo de olhos fechados.',
  ),
];

const List<StatItem> _defaultStats = [
  StatItem(value: 180, suffix: '+', label: 'projetos entregues'),
  StatItem(value: 2, suffix: '', label: 'anos de mercado'),
  StatItem(value: 98, suffix: '%', label: 'clientes satisfeitos'),
];

const BeforeAfterProject _defaultBeforeAfter = BeforeAfterProject(
  beforeImageUrl: 'assets/imagens/ambientes/antes aline.jpeg',
  afterImageUrl: 'assets/imagens/ambientes/depois aline.jpeg',
);

const ShowcaseVideo _defaultVideo = ShowcaseVideo(
  videoUrl: 'assets/videos/snapinsta-1787241165654.mp4',
  title: 'Cozinha planejada entregue',
  subtitle: 'Cozinha · São Paulo',
);

const SpotlightProject _defaultSpotlight = SpotlightProject(
  title: 'Lavanderia Colonial',
  tagline: 'Moldura clássica · ferragens douradas',
  photos: [
    'assets/imagens/ambientes/lavanderia 1 poli.jpeg',
    'assets/imagens/ambientes/lavanderia 2 poli.jpeg',
    'assets/imagens/ambientes/lavanderia 3 poli.jpeg',
  ],
  highlights: [
    SpotlightHighlight(
      label: 'Ferragens douradas',
      description: 'Puxadores sob medida',
      photoIndex: 0,
      position: SpotlightPosition.topLeft,
    ),
    SpotlightHighlight(
      label: 'Vidro canelado',
      description: 'Portas em arco no nicho',
      photoIndex: 0,
      position: SpotlightPosition.center,
    ),
  ],
);

final List<ShowcaseSlide> _defaultSlides = [
  const ShowcaseSlide(
    id: 'capa',
    background: SlideBackground.dark,
    eyebrow: 'DELLALIO',
    title: 'Do seu jeito,\ncom a nossa qualidade',
    imagePath: 'assets/imagens/logo/logo ld.png',
    animationType: SlideAnimationType.fadeUp,
  ),
  const ShowcaseSlide(
    id: 'planejados',
    background: SlideBackground.light,
    badge: '100% SOB MEDIDA',
    title: 'Cada milímetro pensado\npro seu espaço',
    body:
        'Não existe ambiente padrão. Cada projeto é desenhado a partir '
        'das medidas reais do seu imóvel, considerando iluminação, '
        'circulação e uso diário. O resultado é um móvel que parece '
        'ter nascido junto com a parede.',
    imagePath: 'assets/imagens/ambientes/cozinha.jpg',
    animationType: SlideAnimationType.zoomOutPhoto,
  ),
  const ShowcaseSlide(
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
  ),
  const ShowcaseSlide(
    id: 'acabamento',
    background: SlideBackground.light,
    badge: 'ACABAMENTO',
    title: 'O detalhe que se sente\nao tocar',
    body:
        'Cada peça passa por revisão manual antes de sair da fábrica. '
        'Cantos arredondados, superfície lixada em três grãos '
        'e verniz acetinado de alto desempenho.',
    imagePath: 'assets/imagens/ambientes/bancada quarto.jpg',
    animationType: SlideAnimationType.cropInPhoto,
    ctaLabel: 'Solicitar meu projeto',
  ),
];
