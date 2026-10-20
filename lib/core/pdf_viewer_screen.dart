import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dellalio_kit.dart';
import 'theme.dart';

/// Visualizador de PDF inline (com imprimir/compartilhar). Abre pela [url]
/// ou por um [carregar] (ex.: arquivo local da pasta vigiada).
class PdfViewerScreen extends StatefulWidget {
  final String? url;
  final Future<Uint8List> Function()? carregar;
  final String titulo;

  const PdfViewerScreen({
    super.key,
    this.url,
    this.carregar,
    required this.titulo,
  }) : assert(url != null || carregar != null);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Future<Uint8List> _baixarBytes() async {
    if (widget.carregar != null) return widget.carregar!();
    final resposta = await http.get(Uri.parse(widget.url!));
    if (resposta.statusCode != 200) {
      throw Exception('Não foi possível carregar o documento.');
    }
    return resposta.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: Column(
        children: [
          DellalioSubHeader(title: widget.titulo),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: PdfPreview(
                      build: (format) => _baixarBytes(),
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      allowPrinting: true,
                      allowSharing: true,
                      canDebug: false,
                      useActions: true,
                      initialPageFormat: PdfPageFormat.a4,
                      pdfPreviewPageDecoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black45, blurRadius: 10)
                        ],
                      ),
                      maxPageWidth: constraints.maxWidth * 0.95,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
