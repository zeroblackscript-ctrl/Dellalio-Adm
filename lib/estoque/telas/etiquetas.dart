import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../util/quantidade.dart';

/// Conteúdo do QR lido pelo scanner do Gerenciador.
String qrDoMaterial(String id) => 'dellalio://material/$id';

/// Folha A4 de etiqueta adesiva comum: 3 × 7 de 63,5 × 38,1 mm
/// (Pimaco A4363 / Avery L7160).
Future<Uint8List> pdfEtiquetas(List<MaterialEstoque> materiais) async {
  const mm = PdfPageFormat.mm;
  const larg = 63.5 * mm, alt = 38.1 * mm;
  const margemTopo = 15.15 * mm, margemLado = 7.2 * mm, vao = 2.5 * mm;
  const porFolha = 21;

  final doc = pw.Document(title: 'Etiquetas Dellalio');
  for (var inicio = 0; inicio < materiais.length; inicio += porFolha) {
    final pagina = materiais.skip(inicio).take(porFolha).toList();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(children: [
        for (final (i, m) in pagina.indexed)
          pw.Positioned(
            left: margemLado + (i % 3) * (larg + vao),
            top: margemTopo + (i ~/ 3) * alt,
            child: pw.SizedBox(width: larg, height: alt, child: _etiqueta(m)),
          ),
      ]),
    ));
  }
  return doc.save();
}

pw.Widget _etiqueta(MaterialEstoque m) {
  final detalhes = [
    if (m.espessuraMm != null) '${fmtNumero(m.espessuraMm!)} mm',
    m.categoria.rotulo,
    ?m.refFornecedor,
  ].join(' · ');
  return pw.Padding(
    padding: const pw.EdgeInsets.all(3 * PdfPageFormat.mm),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: qrDoMaterial(m.id),
          width: 28 * PdfPageFormat.mm,
          height: 28 * PdfPageFormat.mm,
        ),
        pw.SizedBox(width: 3 * PdfPageFormat.mm),
        pw.Expanded(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(m.nome, maxLines: 3, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(detalhes, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              if (m.local != null) ...[
                pw.SizedBox(height: 3),
                pw.Text(m.local!, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Abre a impressão (com pré-visualização do sistema).
Future<void> imprimirEtiquetas(List<MaterialEstoque> materiais) => Printing.layoutPdf(
  name: 'Etiquetas Dellalio',
  format: PdfPageFormat.a4,
  onLayout: (_) => pdfEtiquetas(materiais),
);
