import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'planilha.dart';

/// Arquivo que chegou (pasta, arrastar ou botão), com o texto extraído uma
/// única vez pra todos os leitores.
class ArquivoEntrada {
  final String nome;

  /// Sem o ponto, minúscula: 'pdf', 'csv', 'xlsx', 'xls', 'xml'.
  final String extensao;
  final Uint8List bytes;

  /// Texto do PDF (por linhas, com o layout preservado) ou da planilha.
  final String texto;

  /// Metadados do PDF/planilha (criador, produtor, título) — onde o DinaBox
  /// costuma se identificar.
  final String metadados;

  /// Linhas da planilha (CSV/XLSX), já como texto.
  final List<List<String>> tabela;

  const ArquivoEntrada({
    required this.nome,
    required this.extensao,
    required this.bytes,
    this.texto = '',
    this.metadados = '',
    this.tabela = const [],
  });

  bool get ehPdf => extensao == 'pdf';
  bool get ehPlanilha =>
      extensao == 'csv' || extensao == 'xlsx' || extensao == 'xls';

  /// PDF sem camada de texto (escaneado): só a IA lê.
  bool get pdfSemTexto => ehPdf && texto.trim().length < 20;

  List<String> get linhas => const LineSplitter().convert(texto);

  static Future<ArquivoEntrada> deArquivo(File arquivo) async =>
      deBytes(p.basename(arquivo.path), await arquivo.readAsBytes());

  static ArquivoEntrada deBytes(String nome, Uint8List bytes) {
    final ext = p.extension(nome).replaceFirst('.', '').toLowerCase();
    if (ext == 'pdf') {
      final (texto, meta) = extrairTextoPdf(bytes);
      return ArquivoEntrada(
        nome: nome,
        extensao: ext,
        bytes: bytes,
        texto: texto,
        metadados: meta,
      );
    }
    if (ext == 'csv' || ext == 'xlsx') {
      final planilha = ext == 'csv' ? lerCsv(bytes) : lerXlsx(bytes);
      return ArquivoEntrada(
        nome: nome,
        extensao: ext,
        bytes: bytes,
        tabela: planilha.linhas,
        texto: planilha.linhas.map((l) => l.join('\t')).join('\n'),
        metadados: planilha.metadados,
      );
    }
    if (ext == 'xml') {
      return ArquivoEntrada(
        nome: nome,
        extensao: ext,
        bytes: bytes,
        texto: utf8.decode(bytes, allowMalformed: true),
      );
    }
    // .xls (binário antigo) e outros: sem leitor local.
    return ArquivoEntrada(nome: nome, extensao: ext, bytes: bytes);
  }
}

/// Texto do PDF com o layout preservado (colunas viram espaços) e os
/// metadados. PDF corrompido devolve vazio — a IA ainda pode tentar.
(String, String) extrairTextoPdf(Uint8List bytes) {
  PdfDocument? doc;
  try {
    doc = PdfDocument(inputBytes: bytes);
    final info = doc.documentInformation;
    final meta = [info.title, info.creator, info.producer, info.subject, info.keywords]
        .where((s) => s.trim().isNotEmpty)
        .join(' | ');
    final texto = PdfTextExtractor(doc).extractText(layoutText: true);
    return (texto, meta);
  } catch (e) {
    debugPrint('PDF sem texto legível: $e');
    return ('', '');
  } finally {
    doc?.dispose();
  }
}
