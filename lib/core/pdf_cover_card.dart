import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// Card compacto de arquivo/PDF. Abre no aplicativo padrão do sistema
/// (navegador / leitor de PDF) via `launchUrl`.
class PdfCoverCard extends StatefulWidget {
  final String name;
  final String url;

  const PdfCoverCard({super.key, required this.name, required this.url});

  @override
  State<PdfCoverCard> createState() => _PdfCoverCardState();
}

class _PdfCoverCardState extends State<PdfCoverCard> {
  bool _hover = false;

  bool get _isPdf {
    final n = widget.name.toLowerCase();
    final u = widget.url.toLowerCase().split('?').first;
    return n.endsWith('.pdf') || u.endsWith('.pdf');
  }

  void _open() {
    final uri = Uri.tryParse(widget.url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _open,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          decoration: BoxDecoration(
            color: _hover ? inkSurfaceHover : inkSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hover ? hairlineNavy : hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: (_isPdf ? panelRust : panelSlate).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  _isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.insert_drive_file_outlined,
                  size: 16,
                  color: _isPdf ? panelRust : panelSlate,
                ),
              ),
              const Spacer(),
              Text(
                widget.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: panelIvory,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _hover ? "abrir" : (_isPdf ? "PDF" : "arquivo"),
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.5,
                  color: _hover ? dellalioGoldSoft : panelSlateDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grade compacta de arquivos pronta pra usar dentro de uma aba. `items` =
/// lista de mapas com `name` e `url` (o formato salvo no Firestore).
class PdfCoverGrid extends StatelessWidget {
  final List<dynamic>? items;
  final String emptyTitle;

  const PdfCoverGrid({
    super.key,
    required this.items,
    this.emptyTitle = "Nenhum arquivo",
  });

  @override
  Widget build(BuildContext context) {
    final list = (items ?? [])
        .whereType<Map>()
        .where((m) => (m['url']?.toString() ?? '').isNotEmpty)
        .toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_outlined, size: 42, color: panelSlateDim),
            const SizedBox(height: 10),
            Text(emptyTitle, style: TextStyle(color: panelSlate, fontSize: 14)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 148,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 118,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final m = list[i];
        return PdfCoverCard(
          name: m['name']?.toString() ?? 'Documento',
          url: m['url'].toString(),
        );
      },
    );
  }
}
