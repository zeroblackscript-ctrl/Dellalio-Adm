import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:xml/xml.dart';

import '../util/normalizar.dart';

class Planilha {
  final List<List<String>> linhas;
  final String metadados;
  const Planilha(this.linhas, [this.metadados = '']);
}

/// CSV com separador detectado sozinho (`,` ou `;` do Excel brasileiro).
Planilha lerCsv(Uint8List bytes) {
  var texto = utf8.decode(bytes, allowMalformed: true);
  if (texto.contains('�')) texto = latin1.decode(bytes); // Excel antigo
  if (texto.startsWith('﻿')) texto = texto.substring(1);
  final linhas = const CsvDecoder()
      .convert(texto)
      .map((l) => l.map((c) => c?.toString().trim() ?? '').toList())
      .where((l) => l.any((c) => c.isNotEmpty))
      .toList();
  return Planilha(linhas);
}

/// XLSX lido direto do zip (primeira aba): `sharedStrings` + `sheet`.
/// Evita o pacote `excel`, que conflita com o `pdf`/`printing`.
Planilha lerXlsx(Uint8List bytes) {
  try {
    final zip = ZipDecoder().decodeBytes(bytes);
    String? ler(String nome) {
      final f = zip.findFile(nome);
      return f == null ? null : utf8.decode(f.content, allowMalformed: true);
    }

    final compartilhadas = <String>[];
    final ss = ler('xl/sharedStrings.xml');
    if (ss != null) {
      for (final si in XmlDocument.parse(ss).findAllElements('si')) {
        compartilhadas.add(si.findAllElements('t').map((t) => t.innerText).join());
      }
    }

    final nomeAba = zip.files
        .map((f) => f.name)
        .where((n) => n.startsWith('xl/worksheets/sheet') && n.endsWith('.xml'))
        .toList()
      ..sort();
    if (nomeAba.isEmpty) return const Planilha([]);
    final aba = XmlDocument.parse(ler(nomeAba.first)!);

    final linhas = <List<String>>[];
    for (final row in aba.findAllElements('row')) {
      final celulas = <int, String>{};
      for (final c in row.findElements('c')) {
        final col = _coluna(c.getAttribute('r') ?? '');
        final tipo = c.getAttribute('t');
        String valor;
        if (tipo == 's') {
          final i = int.tryParse(c.getElement('v')?.innerText ?? '');
          valor = i != null && i < compartilhadas.length ? compartilhadas[i] : '';
        } else if (tipo == 'inlineStr') {
          valor = c.findAllElements('t').map((t) => t.innerText).join();
        } else {
          valor = c.getElement('v')?.innerText ?? '';
        }
        celulas[col < 0 ? celulas.length : col] = valor.trim();
      }
      if (celulas.isEmpty) continue;
      final maior = celulas.keys.reduce((a, b) => a > b ? a : b);
      final linha = List.generate(maior + 1, (i) => celulas[i] ?? '');
      if (linha.any((c) => c.isNotEmpty)) linhas.add(linha);
    }

    final core = ler('docProps/core.xml') ?? '';
    final app = ler('docProps/app.xml') ?? '';
    final meta = '${XmlDocument.parse(core.isEmpty ? '<x/>' : core).innerText} '
        '${XmlDocument.parse(app.isEmpty ? '<x/>' : app).innerText}';
    return Planilha(linhas, meta.trim());
  } catch (_) {
    return const Planilha([]);
  }
}

/// "C12" → 2.
int _coluna(String ref) {
  final letras = RegExp(r'^[A-Z]+').stringMatch(ref.toUpperCase());
  if (letras == null) return -1;
  var n = 0;
  for (final c in letras.codeUnits) {
    n = n * 26 + (c - 64);
  }
  return n - 1;
}

// ------------------------------------------------------------ cabeçalho

enum Coluna {
  descricao,
  quantidade,
  unidade,
  referencia,
  fornecedor,
  largura,
  altura,
  espessura,
  custo,
}

const Map<Coluna, List<String>> _sinonimos = {
  Coluna.descricao: ['descricao', 'item', 'material', 'produto', 'nome', 'discriminacao'],
  Coluna.quantidade: ['quantidade', 'qtd', 'qtde', 'quant', 'qt', 'qtd total'],
  Coluna.unidade: ['unidade', 'un', 'und', 'unid', 'um', 'u m'],
  Coluna.referencia: ['referencia', 'ref', 'codigo', 'cod', 'cod produto', 'sku'],
  Coluna.fornecedor: ['fornecedor', 'marca', 'fabricante'],
  Coluna.largura: ['largura', 'larg'],
  Coluna.altura: ['altura', 'comprimento', 'comp', 'alt'],
  Coluna.espessura: ['espessura', 'esp'],
  Coluna.custo: ['custo', 'valor', 'preco', 'valor unitario', 'preco unitario', 'custo unitario', 'vl unit'],
};

/// Qual coluna é o quê, achado pelos nomes do cabeçalho (sem mapeamento
/// manual). [linhaCabecalho] = índice da linha de cabeçalho.
class MapeamentoColunas {
  final int linhaCabecalho;
  final Map<Coluna, int> colunas;
  const MapeamentoColunas(this.linhaCabecalho, this.colunas);

  bool get valido =>
      colunas.containsKey(Coluna.descricao) &&
      colunas.containsKey(Coluna.quantidade);

  /// Procura nas primeiras 15 linhas a que tiver mais sinônimos.
  static MapeamentoColunas? detectar(List<List<String>> linhas) {
    MapeamentoColunas? melhor;
    for (var i = 0; i < linhas.length && i < 15; i++) {
      final mapa = <Coluna, int>{};
      for (var c = 0; c < linhas[i].length; c++) {
        final cel = normalizar(linhas[i][c]);
        if (cel.isEmpty || cel.length > 30) continue;
        // "valor total" não é custo unitário.
        if (cel.contains('total') && !cel.contains('qtd')) continue;
        for (final e in _sinonimos.entries) {
          if (mapa.containsKey(e.key)) continue;
          if (e.value.any((s) => cel == s || cel.startsWith('$s '))) {
            mapa[e.key] = c;
            break;
          }
        }
      }
      final m = MapeamentoColunas(i, mapa);
      if (m.valido && (melhor == null || mapa.length > melhor.colunas.length)) {
        melhor = m;
      }
    }
    return melhor;
  }

  /// Monta o mapeamento a partir dos índices que a IA devolveu.
  factory MapeamentoColunas.deMapa(int linha, Map<String, dynamic> mapa) {
    final colunas = <Coluna, int>{};
    for (final c in Coluna.values) {
      final v = mapa[c.name];
      if (v is num && v >= 0) colunas[c] = v.toInt();
    }
    return MapeamentoColunas(linha, colunas);
  }
}

/// Número no formato brasileiro ou internacional ("1.250,5", "11,4", "2.5").
double? lerNumeroBr(String s) {
  var t = s.trim().replaceAll(RegExp(r'[R$\s]'), '');
  if (t.isEmpty) return null;
  if (t.contains(',') && t.contains('.')) {
    t = t.lastIndexOf(',') > t.lastIndexOf('.')
        ? t.replaceAll('.', '').replaceAll(',', '.')
        : t.replaceAll(',', '');
  } else if (t.contains(',')) {
    t = t.replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', ''); // "1.250" = mil duzentos e cinquenta
  }
  return double.tryParse(t);
}
