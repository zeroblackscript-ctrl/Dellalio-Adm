import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'edit_before_after_screen.dart';
import 'edit_categories_screen.dart';
import 'edit_mdf_colors_screen.dart';
import 'edit_showcase_slides_screen.dart';
import 'edit_showcase_video_screen.dart';
import 'edit_spotlight_project_screen.dart';
import 'edit_stats_screen.dart';
import 'edit_testimonials_screen.dart';
import 'preview/phone_frame.dart';
import 'preview/preview_before_after_section.dart';
import 'preview/preview_categories_section.dart';
import 'preview/preview_content_service.dart';
import 'preview/preview_home_showcase.dart';
import 'preview/preview_mdf_colors_section.dart';
import 'preview/preview_models.dart' as preview;
import 'preview/preview_numbers_section.dart';
import 'preview/preview_slides_walkthrough.dart';
import 'preview/preview_spotlight_section.dart';
import 'preview/preview_testimonials_section.dart';
import 'preview/preview_video_section.dart';

/// Aba "App Clientes" — hub que reúne todo o conteúdo da vitrine do app
/// Dellalio Clientes (hoje fixo no código dele) editável por aqui, gravando
/// na coleção Firestore `site_content` compartilhada pelos dois apps.
///
/// O celular à direita fica sempre montado. Sem seção selecionada, ele
/// navega o app inteiro (Abertura/Vitrine/Trabalho). Ao abrir uma seção, o
/// conteúdo à esquerda troca in-place pro editor dela (sem navegar de
/// tela) e o celular passa a focar só naquela seção, ao vivo.
class SiteContentScreen extends StatefulWidget {
  const SiteContentScreen({super.key});

  @override
  State<SiteContentScreen> createState() => _SiteContentScreenState();
}

enum _PreviewMode { onboarding, vitrine, ourWork }

class _SiteContentScreenState extends State<SiteContentScreen> {
  _PreviewMode _mode = _PreviewMode.vitrine;
  final _service = PreviewContentService();

  int? _selectedIndex;
  dynamic _liveDraft;

  static final List<_SiteSection> _sections = [
    _SiteSection(
      icon: Icons.grid_view_outlined,
      title: "Categorias de ambientes",
      subtitle: "Grade de ambientes da vitrine",
      editorBuilder: ({onBack, onDraftChanged}) => EditCategoriesScreen(
        onBack: onBack,
        onDraftChanged: onDraftChanged,
      ),
      previewBuilder: (draft) => PreviewCategoriesSection(
        isActive: true,
        categories: (draft as List<Map<String, dynamic>>)
            .map(preview.RoomCategory.fromMap)
            .toList(),
      ),
    ),
    _SiteSection(
      icon: Icons.palette_outlined,
      title: "Cores de MDF",
      subtitle: "Cores mais usadas exibidas na vitrine",
      editorBuilder: ({onBack, onDraftChanged}) => EditMdfColorsScreen(
        onBack: onBack,
        onDraftChanged: onDraftChanged,
      ),
      previewBuilder: (draft) => PreviewMdfColorsSection(
        isActive: true,
        colors: (draft as List<Map<String, dynamic>>)
            .map(preview.MdfColorSwatch.fromMap)
            .toList(),
      ),
    ),
    _SiteSection(
      icon: Icons.format_quote_outlined,
      title: "Depoimentos",
      subtitle: "O que os clientes dizem",
      editorBuilder: ({onBack, onDraftChanged}) => EditTestimonialsScreen(
        onBack: onBack,
        onDraftChanged: onDraftChanged,
      ),
      previewBuilder: (draft) => PreviewTestimonialsSection(
        isActive: true,
        items: (draft as List<Map<String, dynamic>>)
            .map(preview.Testimonial.fromMap)
            .toList(),
      ),
    ),
    _SiteSection(
      icon: Icons.bar_chart_outlined,
      title: "Números da empresa",
      subtitle: "Projetos entregues, anos de mercado...",
      editorBuilder: ({onBack, onDraftChanged}) =>
          EditStatsScreen(onBack: onBack, onDraftChanged: onDraftChanged),
      previewBuilder: (draft) => PreviewNumbersSection(
        isActive: true,
        items: (draft as List<Map<String, dynamic>>)
            .map(preview.StatItem.fromMap)
            .toList(),
      ),
    ),
    _SiteSection(
      icon: Icons.compare_outlined,
      title: "Antes e depois",
      subtitle: "Comparativo de transformação",
      editorBuilder: ({onBack, onDraftChanged}) => EditBeforeAfterScreen(
        onBack: onBack,
        onDraftChanged: onDraftChanged,
      ),
      previewBuilder: (draft) {
        final map = draft as Map<String, dynamic>;
        return PreviewBeforeAfterSection(
          isActive: true,
          project: preview.BeforeAfterProject(
            beforeImageUrl: map['beforeImageUrl'] as String?,
            afterImageUrl: map['afterImageUrl'] as String?,
          ),
        );
      },
    ),
    _SiteSection(
      icon: Icons.play_circle_outline,
      title: "Vídeo de destaque",
      subtitle: "Vídeo do projeto entregue",
      editorBuilder: ({onBack, onDraftChanged}) => EditShowcaseVideoScreen(
        onBack: onBack,
        onDraftChanged: onDraftChanged,
      ),
      previewBuilder: (draft) {
        final map = draft as Map<String, dynamic>;
        return PreviewVideoSection(
          isActive: true,
          video: preview.ShowcaseVideo(
            videoUrl: map['videoUrl'] as String? ?? '',
            title: map['title'] as String? ?? '',
            subtitle: map['subtitle'] as String? ?? '',
          ),
        );
      },
    ),
    _SiteSection(
      icon: Icons.star_outline,
      title: "Projeto em destaque",
      subtitle: "Carrossel de fotos com balões",
      editorBuilder: ({onBack, onDraftChanged}) => EditSpotlightProjectScreen(
        onBack: onBack,
        onDraftChanged: onDraftChanged,
      ),
      previewBuilder: (draft) {
        final map = draft as Map<String, dynamic>;
        final highlights = (map['highlights'] as List? ?? [])
            .map((e) => preview.SpotlightHighlight.fromMap(e))
            .toList();
        final photos = (map['photos'] as List? ?? [])
            .map((e) => e.toString())
            .toList();
        return PreviewSpotlightSection(
          isActive: true,
          project: preview.SpotlightProject(
            title: map['title'] as String? ?? '',
            tagline: map['tagline'] as String? ?? '',
            photos: photos,
            highlights: highlights,
          ),
        );
      },
    ),
    _SiteSection(
      icon: Icons.view_carousel_outlined,
      title: "Slides de abertura",
      subtitle: "Onboarding e \"Nosso trabalho\"",
      editorBuilder: ({onBack, onDraftChanged}) => EditShowcaseSlidesScreen(
        onBack: onBack,
        onDraftChanged: onDraftChanged,
      ),
      previewBuilder: (draft) => PreviewSlidesWalkthrough(
        slides: (draft as List<Map<String, dynamic>>)
            .map(preview.ShowcaseSlide.fromMap)
            .toList(),
      ),
    ),
  ];

  void _openSection(int index) {
    setState(() {
      _selectedIndex = index;
      _liveDraft = null;
    });
  }

  void _closeSection() {
    setState(() {
      _selectedIndex = null;
      _liveDraft = null;
    });
  }

  Widget _buildModeTab(_PreviewMode mode, String label) {
    final active = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? dellalioGold.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: active ? dellalioGold : hairline),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? dellalioGoldSoft : panelSlate,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralPreview() {
    switch (_mode) {
      case _PreviewMode.vitrine:
        return const PreviewHomeShowcase();
      case _PreviewMode.onboarding:
        return StreamBuilder<List<preview.ShowcaseSlide>>(
          stream: _service.showcaseSlides(),
          builder: (context, snap) =>
              PreviewSlidesWalkthrough(slides: snap.data ?? const []),
        );
      case _PreviewMode.ourWork:
        return StreamBuilder<List<preview.ShowcaseSlide>>(
          stream: _service.showcaseSlides(),
          builder: (context, snap) => PreviewSlidesWalkthrough(
            slides: snap.data ?? const [],
            withAppBar: true,
          ),
        );
    }
  }

  Widget _buildLeftPane() {
    if (_selectedIndex == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "App Clientes",
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w500,
                fontSize: 20,
                color: dellalioTitle,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Conteúdo da vitrine do app cliente — o celular ao lado mostra "
              "o resultado ao vivo.",
              style: TextStyle(color: panelSlateDim, fontSize: 11.5),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _sections.length; i++)
              _SectionListTile(
                section: _sections[i],
                delayIndex: i,
                onTap: () => _openSection(i),
              ),
          ],
        ),
      );
    }
    final section = _sections[_selectedIndex!];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      child: section.editorBuilder(
        onBack: _closeSection,
        onDraftChanged: (draft) => setState(() => _liveDraft = draft),
      ),
    );
  }

  Widget _buildRightPane() {
    if (_selectedIndex == null) {
      return Column(
        children: [
          Row(
            children: [
              _buildModeTab(_PreviewMode.onboarding, "Abertura"),
              const SizedBox(width: 6),
              _buildModeTab(_PreviewMode.vitrine, "Vitrine"),
              const SizedBox(width: 6),
              _buildModeTab(_PreviewMode.ourWork, "Trabalho"),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: PhoneFrame(child: _buildGeneralPreview())),
        ],
      );
    }
    final section = _sections[_selectedIndex!];
    return Column(
      children: [
        Text(
          section.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: panelSlateDim,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: PhoneFrame(
            child: _liveDraft == null
                ? const ColoredBox(color: Colors.black12)
                : section.previewBuilder(_liveDraft),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: _buildLeftPane()),
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: inkSurface,
                border: Border(left: BorderSide(color: hairline)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: _buildRightPane(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteSection {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget Function({
    VoidCallback? onBack,
    ValueChanged<dynamic>? onDraftChanged,
  })
  editorBuilder;
  final Widget Function(dynamic draft) previewBuilder;

  const _SiteSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.editorBuilder,
    required this.previewBuilder,
  });
}

/// Linha compacta de altura natural (sem aspect ratio fixo) — evita o
/// overflow que um GridView com childAspectRatio fixo causaria conforme a
/// coluna esquerda fica mais estreita.
class _SectionListTile extends StatefulWidget {
  final _SiteSection section;
  final int delayIndex;
  final VoidCallback onTap;

  const _SectionListTile({
    required this.section,
    required this.delayIndex,
    required this.onTap,
  });

  @override
  State<_SectionListTile> createState() => _SectionListTileState();
}

class _SectionListTileState extends State<_SectionListTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _hover ? inkSurfaceHover : inkSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _hover ? hairlineNavy : hairline),
            ),
            child: Row(
              children: [
                Icon(
                  widget.section.icon,
                  size: 18,
                  color: _hover ? dellalioGoldSoft : panelSlate,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.section.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: panelIvory,
                        ),
                      ),
                      Text(
                        widget.section.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: panelSlateDim, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: _hover ? dellalioGoldSoft : panelSlateDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
