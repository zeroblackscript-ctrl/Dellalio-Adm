import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import '../util/datas.dart';
import '../util/quantidade.dart';

/// Comprovante em A4 (o mesmo no Cérebro e no Gerenciador): cabeçalho com
/// número e data, quem entregou/recebeu, destino, a tabela dos materiais
/// com o saldo antes e depois, observação, declaração e assinaturas. Sem
/// assinatura digital, sai a linha em branco para assinar no papel.
Future<Uint8List> pdfComprovante(Comprovante c) async {
  final doc = pw.Document(
    title: '${c.tipo.titulo} ${c.numeroFormatado}',
    author: 'Dellalio Móveis Planejados',
  );
  final retirada = c.tipo == TipoComprovante.retirada;
  final escuro = PdfColor.fromHex('#0C1A30');
  final ouro = PdfColor.fromHex('#C9A227');
  final cinza = PdfColors.grey700;
  final linha = PdfColors.grey400;
  final assinatura = c.assinaturaPng == null ? null : pw.MemoryImage(base64Decode(c.assinaturaPng!));

  pw.Widget rotulo(String t) => pw.Text(
    t.toUpperCase(),
    style: pw.TextStyle(fontSize: 7.5, color: cinza, letterSpacing: 1.2, fontWeight: pw.FontWeight.bold),
  );

  pw.Widget campo(String r, String? v, {double flex = 1}) => pw.Expanded(
    flex: (flex * 10).round(),
    child: pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 7),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: linha, width: 0.6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          rotulo(r),
          pw.SizedBox(height: 3),
          pw.Text(v == null || v.isEmpty ? '-' : v, style: const pw.TextStyle(fontSize: 10.5)),
        ],
      ),
    ),
  );

  pw.Widget assinar(String titulo, String nome, {pw.ImageProvider? imagem}) => pw.Expanded(
    child: pw.Column(
      children: [
        pw.SizedBox(
          height: 58,
          child: imagem == null
              ? pw.SizedBox()
              : pw.Image(imagem, fit: pw.BoxFit.contain),
        ),
        pw.Container(height: 0.8, color: PdfColors.grey800),
        pw.SizedBox(height: 4),
        pw.Text(nome, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text(titulo, style: pw.TextStyle(fontSize: 8, color: cinza)),
      ],
    ),
  );

  final celula = const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5);
  pw.Widget cab(String t, {pw.TextAlign a = pw.TextAlign.left}) => pw.Padding(
    padding: celula,
    child: pw.Text(t, textAlign: a, style: pw.TextStyle(fontSize: 8.5, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
  );
  pw.Widget cel(String t, {pw.TextAlign a = pw.TextAlign.left, bool forte = false}) => pw.Padding(
    padding: celula,
    child: pw.Text(t, textAlign: a, style: pw.TextStyle(fontSize: 9.5, fontWeight: forte ? pw.FontWeight.bold : null)),
  );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 34, 36, 34),
    footer: (ctx) => pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            'Registrado ${c.registradoNo == null ? '' : 'no ${c.registradoNo} '}em ${fmtCompleta(c.criadoEm ?? DateTime.now())} · código ${c.id}',
            style: pw.TextStyle(fontSize: 7, color: cinza),
          ),
        ),
        pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 7, color: cinza)),
      ],
    ),
    build: (ctx) => [
      // Cabeçalho
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
        color: escuro,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Dellalio', style: pw.TextStyle(fontSize: 22, color: ouro, fontWeight: pw.FontWeight.bold)),
                  pw.Text('MÓVEIS PLANEJADOS · CONTROLE DE ESTOQUE', style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey300, letterSpacing: 1.4)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(c.tipo.titulo.toUpperCase(), style: pw.TextStyle(fontSize: 11, color: PdfColors.white, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
                pw.SizedBox(height: 2),
                pw.Text('Nº ${c.numeroFormatado}', style: pw.TextStyle(fontSize: 20, color: ouro, fontWeight: pw.FontWeight.bold)),
                pw.Text(fmtCompleta(c.criadoEm ?? DateTime.now()), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey300)),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 14),

      // Quem e para onde
      if (retirada) ...[
        pw.Row(children: [
          campo('Entregue a (quem recebeu)', c.recebedorNome, flex: 1.6),
          campo('Função / setor', c.recebedorFuncao),
        ]),
        pw.Row(children: [
          campo('Entregue por', c.responsavelNome, flex: 1.6),
          campo('Finalidade', c.motivo),
        ]),
        pw.Row(children: [
          campo('Cliente', c.clienteNome, flex: 1.6),
          campo('Projeto / obra', c.projetoNome),
        ]),
      ] else ...[
        pw.Row(children: [
          campo('Recebido de (fornecedor / pessoa)', c.origemNome, flex: 1.6),
          campo('Nota fiscal', c.notaNumero),
        ]),
        pw.Row(children: [
          campo('Conferido e incluído por', c.responsavelNome, flex: 1.6),
          campo('Motivo da entrada', c.motivo),
        ]),
        if (c.clienteNome != null || c.projetoNome != null)
          pw.Row(children: [
            campo('Cliente', c.clienteNome, flex: 1.6),
            campo('Projeto / obra', c.projetoNome),
          ]),
      ],
      pw.SizedBox(height: 16),

      // Materiais
      pw.Text('Materiais ${retirada ? 'retirados' : 'incluídos'} (${c.itens.length})',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder.all(color: linha, width: 0.6),
        columnWidths: const {
          0: pw.FixedColumnWidth(22),
          1: pw.FlexColumnWidth(5),
          2: pw.FlexColumnWidth(2.2),
          3: pw.FlexColumnWidth(1.8),
          4: pw.FlexColumnWidth(2.4),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: escuro),
            children: [
              cab('#'),
              cab('Material'),
              cab('Local'),
              cab('Quantidade', a: pw.TextAlign.right),
              cab('Estoque antes > depois', a: pw.TextAlign.right),
            ],
          ),
          for (final (i, it) in c.itens.indexed)
            pw.TableRow(
              decoration: pw.BoxDecoration(color: i.isOdd ? PdfColors.grey100 : PdfColors.white),
              children: [
                cel('${i + 1}'),
                cel(it.materialNome, forte: true),
                cel(it.local ?? '-'),
                cel(fmtQtd(it.quantidade, it.unidade), a: pw.TextAlign.right, forte: true),
                cel('${fmtNumero(it.fisicoAntes)} > ${fmtNumero(it.fisicoDepois)} ${it.unidade.sigla}', a: pw.TextAlign.right),
              ],
            ),
        ],
      ),
      pw.SizedBox(height: 14),

      // Observação
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: linha, width: 0.6)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            rotulo('Observação'),
            pw.SizedBox(height: 3),
            pw.Text(c.observacao ?? '-', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
      pw.SizedBox(height: 16),

      // Declaração e assinaturas
      pw.Text(
        retirada
            ? 'Declaro que recebi da Dellalio Móveis Planejados os materiais relacionados acima, nas quantidades '
                  'indicadas, e me responsabilizo pelo seu uso na finalidade informada.'
            : 'Os materiais relacionados acima foram conferidos e incluídos no estoque da Dellalio Móveis Planejados '
                  'nas quantidades indicadas.',
        style: const pw.TextStyle(fontSize: 9.5),
      ),
      pw.SizedBox(height: 26),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: retirada
            ? [
                assinar('Recebido por${c.recebedorFuncao == null ? '' : ' · ${c.recebedorFuncao}'}', c.recebedorNome ?? '', imagem: assinatura),
                pw.SizedBox(width: 36),
                assinar('Entregue por', c.responsavelNome),
              ]
            : [
                assinar('Entregue por', c.origemNome ?? ''),
                pw.SizedBox(width: 36),
                assinar('Conferido por', c.responsavelNome, imagem: assinatura),
              ],
      ),
      if (assinatura != null) ...[
        pw.SizedBox(height: 8),
        pw.Text('Assinatura coletada na tela do celular no momento da ${retirada ? 'retirada' : 'entrada'}.',
            style: pw.TextStyle(fontSize: 7.5, color: cinza)),
      ],
    ],
  ));
  return doc.save();
}

/// "comprovante_retirada_00042.pdf".
String nomeArquivoComprovante(Comprovante c) =>
    'comprovante_${c.tipo.name}_${c.numeroFormatado}.pdf';
