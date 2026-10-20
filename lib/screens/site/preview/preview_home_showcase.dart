import 'package:flutter/material.dart';

import 'preview_before_after_section.dart';
import 'preview_categories_section.dart';
import 'preview_content_service.dart';
import 'preview_mdf_colors_section.dart';
import 'preview_models.dart';
import 'preview_numbers_section.dart';
import 'preview_spotlight_section.dart';
import 'preview_testimonials_section.dart';
import 'preview_theme.dart';
import 'preview_video_section.dart';

/// Passeio navegável pela vitrine inteira (as 7 seções da home do app
/// cliente), lendo ao vivo o que está salvo em `site_content` — arraste
/// pra cima/baixo ou toque nos pontinhos pra folhear, igual no app real.
class PreviewHomeShowcase extends StatefulWidget {
  const PreviewHomeShowcase({super.key});

  @override
  State<PreviewHomeShowcase> createState() => _PreviewHomeShowcaseState();
}

class _PreviewHomeShowcaseState extends State<PreviewHomeShowcase> {
  final _service = PreviewContentService();
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBg,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            pageSnapping: true,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: 7,
            itemBuilder: (ctx, i) {
              switch (i) {
                case 0:
                  return StreamBuilder<List<MdfColorSwatch>>(
                    stream: _service.mdfColors(),
                    builder: (context, snap) => PreviewMdfColorsSection(
                      isActive: _currentPage == 0,
                      colors: snap.data ?? const [],
                    ),
                  );
                case 1:
                  return StreamBuilder<BeforeAfterProject>(
                    stream: _service.beforeAfter(),
                    builder: (context, snap) => PreviewBeforeAfterSection(
                      isActive: _currentPage == 1,
                      project: snap.data ?? const BeforeAfterProject(),
                    ),
                  );
                case 2:
                  return StreamBuilder<ShowcaseVideo>(
                    stream: _service.showcaseVideo(),
                    builder: (context, snap) => PreviewVideoSection(
                      isActive: _currentPage == 2,
                      video:
                          snap.data ??
                          const ShowcaseVideo(
                            videoUrl: '',
                            title: '',
                            subtitle: '',
                          ),
                    ),
                  );
                case 3:
                  return StreamBuilder<SpotlightProject>(
                    stream: _service.spotlightProject(),
                    builder: (context, snap) => PreviewSpotlightSection(
                      isActive: _currentPage == 3,
                      project:
                          snap.data ??
                          const SpotlightProject(
                            title: '',
                            tagline: '',
                            photos: [],
                            highlights: [],
                          ),
                    ),
                  );
                case 4:
                  return StreamBuilder<List<StatItem>>(
                    stream: _service.stats(),
                    builder: (context, snap) => PreviewNumbersSection(
                      isActive: _currentPage == 4,
                      items: snap.data ?? const [],
                    ),
                  );
                case 5:
                  return StreamBuilder<List<Testimonial>>(
                    stream: _service.testimonials(),
                    builder: (context, snap) => PreviewTestimonialsSection(
                      isActive: _currentPage == 5,
                      items: snap.data ?? const [],
                    ),
                  );
                case 6:
                  return StreamBuilder<List<RoomCategory>>(
                    stream: _service.categories(),
                    builder: (context, snap) => PreviewCategoriesSection(
                      isActive: _currentPage == 6,
                      categories: snap.data ?? const [],
                    ),
                  );
                default:
                  return const SizedBox.shrink();
              }
            },
          ),
          _buildSideDots(),
        ],
      ),
    );
  }

  Widget _buildSideDots() {
    return Positioned(
      right: 10,
      top: 0,
      bottom: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(7, (i) {
            final active = i == _currentPage;
            return GestureDetector(
              onTap: () => _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(vertical: 3),
                width: active ? 8 : 5,
                height: active ? 18 : 5,
                decoration: BoxDecoration(
                  color: active ? AppColors.gold : Colors.white38,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
