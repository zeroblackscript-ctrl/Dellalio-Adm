import '../models/enums.dart';
import '../util/normalizar.dart';
import '../util/quantidade.dart';
import 'arquivo_entrada.dart';
import 'canal_ia.dart';
import 'leitor.dart';
import 'parser_linha.dart';
import 'planilha.dart';

/// CSV/XLSX genérico (lista montada à mão no Excel, ou exportada). Acha o
/// cabeçalho sozinho pelos sinônimos; sem cabeçalho, pergunta à IA só o
/// mapeamento das colunas; sem IA, deduz pelas colunas.
class LeitorPlanilha implements LeitorLista {
  LeitorPlanilha({CanalIA? ia}) : _ia = ia;
  final CanalIA? _ia;

  @override
  String get nome => 'Planilha';

  @override
  Future<double> reconhece(ArquivoEntrada entrada) async {
    if (!entrada.ehPlanilha || entrada.tabela.isEmpty) return 0;
    return MapeamentoColunas.detectar(entrada.tabela) != null ? 0.9 : 0.5;
  }

  @override
  Future<ListaLida> ler(ArquivoEntrada entrada) async {
    final linhas = entrada.tabela;
    var mapa = MapeamentoColunas.detectar(linhas);
    var confianca = 0.9;
    if (mapa == null) {
      mapa = await _mapaPelaIA(linhas);
      confianca = 0.8;
    }
    if (mapa == null || !mapa.valido) {
      mapa = _mapaDeduzido(linhas);
      confianca = 0.6;
    }
    if (mapa == null) {
      return ListaLida(
        software: SoftwareLista.planilha,
        itens: const [],
        confianca: 0,
        textoExtraido: entrada.texto,
      );
    }
    final itens = itensDaTabela(linhas, mapa);
    // Linhas acima do cabeçalho costumam ter "Cliente: X".
    final topo = linhas
        .take(mapa.linhaCabecalho < 0 ? 0 : mapa.linhaCabecalho)
        .map((l) => l.where((c) => c.isNotEmpty).join(': '))
        .toList();
    return ListaLida(
      software: SoftwareLista.planilha,
      clienteNome: campoCabecalho(topo, const ['cliente']),
      projetoNome: campoCabecalho(topo, const ['projeto', 'ambiente', 'obra']),
      itens: itens,
      confianca: itens.isEmpty ? 0 : confianca,
      textoExtraido: entrada.texto,
    );
  }

  static List<ItemLido> itensDaTabela(
    List<List<String>> linhas,
    MapeamentoColunas mapa,
  ) {
    String? cel(List<String> l, Coluna c) {
      final i = mapa.colunas[c];
      if (i == null || i >= l.length) return null;
      final v = l[i].trim();
      return v.isEmpty ? null : v;
    }

    final itens = <ItemLido>[];
    CategoriaMaterial? grupo;
    for (final l in linhas.skip(mapa.linhaCabecalho + 1)) {
      final desc = cel(l, Coluna.descricao);
      if (desc == null) continue;
      final qtdTexto = cel(l, Coluna.quantidade);
      // Linha só com texto pode ser cabeçalho de grupo ("FERRAGENS").
      if (qtdTexto == null) {
        grupo = categoriaDoCabecalho(desc) ?? grupo;
        continue;
      }
      if (linhaIgnorada(desc)) continue;
      // Quantidade às vezes vem com a unidade junto ("11,4 m²").
      final qm = RegExp(r'^([\d.,]+)\s*(.*)$').firstMatch(qtdTexto);
      final qtd = lerNumeroBr(qm?[1] ?? qtdTexto);
      if (qtd == null || qtd <= 0) continue;
      final cat = grupo ?? inferirCategoria(desc);
      final unidade = cel(l, Coluna.unidade) ??
          ((qm?[2] ?? '').isNotEmpty ? qm![2]! : unidadeDoGrupo(cat) ?? 'un');
      itens.add(ItemLido(
        descricao: desc,
        refFornecedor: cel(l, Coluna.referencia),
        fornecedorNome: cel(l, Coluna.fornecedor),
        categoria: cat,
        quantidade: qtd,
        unidade: unidade,
        larguraMm: lerNumeroBr(cel(l, Coluna.largura) ?? ''),
        alturaMm: lerNumeroBr(cel(l, Coluna.altura) ?? ''),
        espessuraMm: lerNumeroBr(cel(l, Coluna.espessura) ?? '') ??
            (cat == CategoriaMaterial.chapa || cat == CategoriaMaterial.fita
                ? medidasMm(desc).where((m) => m <= 60).firstOrNull
                : null),
        custoUnitario: lerNumeroBr(cel(l, Coluna.custo) ?? ''),
      ));
    }
    return itens;
  }

  Future<MapeamentoColunas?> _mapaPelaIA(List<List<String>> linhas) async {
    try {
      final r = await (_ia ?? CanalIA.padrao).mapearColunas(
        linhas.take(15).toList(),
      );
      if (r == null) return null;
      return MapeamentoColunas.deMapa(
        (r['linhaCabecalho'] as num?)?.toInt() ?? -1,
        Map<String, dynamic>.from(r['colunas'] as Map? ?? const {}),
      );
    } catch (_) {
      return null;
    }
  }

  /// Sem cabeçalho e sem IA: coluna de texto mais longo = descrição,
  /// primeira coluna numérica depois dela = quantidade.
  static MapeamentoColunas? _mapaDeduzido(List<List<String>> linhas) {
    if (linhas.isEmpty) return null;
    final largura = linhas.map((l) => l.length).reduce((a, b) => a > b ? a : b);
    int? desc, qtd;
    var maiorTexto = 0.0;
    for (var c = 0; c < largura; c++) {
      final valores = linhas
          .map((l) => c < l.length ? l[c] : '')
          .where((v) => v.isNotEmpty)
          .toList();
      if (valores.isEmpty) continue;
      final numericos =
          valores.where((v) => lerNumeroBr(v) != null).length / valores.length;
      final media =
          valores.fold<int>(0, (s, v) => s + v.length) / valores.length;
      if (numericos < 0.3 && media > maiorTexto) {
        maiorTexto = media;
        desc = c;
      } else if (numericos > 0.7 && qtd == null && desc != null) {
        qtd = c;
      }
    }
    if (desc == null || qtd == null) return null;
    return MapeamentoColunas(
      -1,
      {Coluna.descricao: desc, Coluna.quantidade: qtd},
    );
  }
}
