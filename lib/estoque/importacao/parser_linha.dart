import '../models/enums.dart';
import '../util/normalizar.dart';
import '../util/quantidade.dart';
import 'conversor_unidades.dart';
import 'leitor.dart';
import 'planilha.dart';

/// Peças comuns aos leitores de PDF de texto (DinaBox e genérico): grupo
/// atual, linhas a ignorar e extração de "descrição + quantidade + unidade".

/// Cabeçalho de grupo ("CHAPAS", "Fitas de borda", "FERRAGENS"...) →
/// categoria. Só vale para linha sem número.
CategoriaMaterial? categoriaDoCabecalho(String linha) {
  final n = normalizar(linha);
  if (n.isEmpty || n.length > 40 || RegExp(r'\d').hasMatch(n)) return null;
  bool comeca(List<String> ps) => ps.any((p) => n == p || n.startsWith('$p '));
  // TODO(arquivo-real): conferir os nomes exatos dos grupos no DinaBox.
  if (comeca(['chapas', 'chapa', 'paineis', 'painel', 'mdf', 'mdp', 'compensados', 'chapas e paineis', 'materiais'])) {
    return CategoriaMaterial.chapa;
  }
  if (comeca(['fitas', 'fita de borda', 'fitas de borda', 'bordas', 'fita borda', 'acabamento de bordas'])) {
    return CategoriaMaterial.fita;
  }
  if (comeca(['ferragens', 'ferragem', 'dobradicas', 'corredicas', 'puxadores'])) {
    return CategoriaMaterial.ferragem;
  }
  if (comeca(['acessorios', 'acessorio'])) return CategoriaMaterial.acessorio;
  if (comeca(['insumos', 'insumo', 'consumiveis', 'diversos'])) {
    return CategoriaMaterial.insumo;
  }
  if (comeca(['sobras', 'retalhos'])) return CategoriaMaterial.sobra;
  return null;
}

/// Linhas que nunca são item: totais, custos, cabeçalho/rodapé de página,
/// cabeçalho da tabela.
bool linhaIgnorada(String linha) {
  final n = normalizar(linha);
  if (n.isEmpty) return true;
  // TODO(arquivo-real): acrescentar os rodapés/cabeçalhos reais do DinaBox.
  const inicios = [
    'total', 'subtotal', 'sub total', 'custo', 'valor total', 'pagina', 'pag ',
    'impresso', 'gerado', 'data', 'emitido', 'observ', 'obs', 'assinatura',
    'lista de compras', 'lista de corte', 'cliente', 'projeto', 'ambiente',
    'obra', 'telefone', 'endereco', 'vendedor', 'responsavel', 'www', 'http',
  ];
  if (inicios.any((i) => n.startsWith(i))) return true;
  if (n.contains('dinabox')) return true;
  // Cabeçalho da tabela: dois ou mais nomes de coluna e nenhum número.
  const colunas = ['descricao', 'material', 'qtd', 'quantidade', 'un', 'unidade', 'ref', 'codigo', 'valor', 'item'];
  final t = n.split(' ');
  if (!RegExp(r'\d').hasMatch(n) && t.where(colunas.contains).length >= 2) {
    return true;
  }
  return false;
}

/// "Cliente: Rodrigues", "Projeto - Cozinha".
String? campoCabecalho(List<String> linhas, List<String> rotulos) {
  for (final l in linhas.take(40)) {
    final m = RegExp(r'^\s*([A-Za-zÀ-ÿ ]+?)\s*[:\-–]\s*(.+?)\s*$').firstMatch(l);
    if (m == null) continue;
    final rotulo = normalizar(m[1]!);
    if (rotulos.contains(rotulo)) {
      // Corta colunas vizinhas no mesmo nível ("Cliente: X     Data: Y").
      final v = m[2]!.split(RegExp(r'\s{3,}')).first.trim();
      if (v.isNotEmpty) return v;
    }
  }
  return null;
}

final RegExp _numero = RegExp(r'^\d{1,3}(?:\.\d{3})*(?:,\d+)?$|^\d+(?:[.,]\d+)?$');
final RegExp _numeroUnidadeColado = RegExp(
  r'^(\d+(?:[.,]\d+)?)([a-zA-Zçªº²]+\.?)$',
);
final RegExp _preco = RegExp(r'R\$\s*[\d.,]+');
final RegExp _refEmTexto = RegExp(
  r'\(?\s*(?<![A-Za-zÀ-ÿ])(?:ref|refer[eê]ncia|c[oó]d(?:igo)?)(?![A-Za-zÀ-ÿ])\.?\s*[:.]?\s*([A-Za-z0-9][A-Za-z0-9.\-/]+)\s*\)?',
  caseSensitive: false,
);

bool _ehNumero(String t) => _numero.hasMatch(t);

/// Primeiro token parece código de produto ("DB-35AM", "1052-18-LF")?
bool _pareceCodigo(String t) =>
    t.length >= 3 &&
    RegExp(r'\d').hasMatch(t) &&
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-./]+$').hasMatch(t) &&
    (t.contains('-') || RegExp(r'[A-Za-z]').hasMatch(t)) &&
    !RegExp(r'^\d+(mm|cm|m|x\d+)$', caseSensitive: false).hasMatch(t);

/// Extrai um item de uma linha de texto. Formatos aceitos (em colunas
/// separadas por espaços):
///   `[REF] Descrição ... 12 un`, `Descrição 11,4 m²`, `Descrição 6 ch 312,40`,
///   `Descrição 11,4m²`, `Descrição (ref. 1052-18-LF) 3 chapas`.
/// [unidadePadrao] entra quando a linha só traz o número.
ItemLido? itemDaLinha(
  String linha, {
  CategoriaMaterial? categoria,
  String? unidadePadrao,
}) {
  var texto = linha.replaceAll(_preco, ' ').trim();
  if (texto.isEmpty) return null;

  String? ref;
  final refM = _refEmTexto.firstMatch(texto);
  if (refM != null && RegExp(r'\d').hasMatch(refM[1]!)) {
    ref = refM[1];
    texto = texto.replaceRange(refM.start, refM.end, ' ');
  }

  var tokens = texto.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  // Separa "11,4m²" em "11,4" + "m²".
  tokens = [
    for (final t in tokens)
      if (_numeroUnidadeColado.firstMatch(t) case final m?
          when ehUnidade(m[2]!) && !_ehMedidaDeDescricao(t))
        ...[m[1]!, m[2]!]
      else
        t,
  ];
  if (tokens.length < 2) return null;

  // Coluna de código no início.
  if (ref == null && tokens.length >= 3 && _pareceCodigo(tokens.first)) {
    ref = tokens.first;
    tokens = tokens.sublist(1);
  }

  // Do fim pro começo: último "número + unidade".
  int? iQtd;
  String? unidade;
  for (var i = tokens.length - 1; i > 0; i--) {
    if (ehUnidade(tokens[i]) && _ehNumero(tokens[i - 1])) {
      iQtd = i - 1;
      unidade = tokens[i];
      break;
    }
  }
  // Sem unidade: primeiro número depois da descrição (o resto é preço).
  if (iQtd == null) {
    for (var i = 1; i < tokens.length; i++) {
      if (_ehNumero(tokens[i]) && !_ehNumero(tokens[i - 1]) ||
          _ehNumero(tokens[i]) && i == tokens.length - 1) {
        // Precisa ter só números depois, senão é medida no meio do nome.
        if (tokens.sublist(i).every(_ehNumero)) {
          iQtd = i;
          break;
        }
      }
    }
    unidade = unidadePadrao;
  }
  if (iQtd == null || iQtd == 0 || unidade == null) return null;

  final qtd = lerNumeroBr(tokens[iQtd]);
  if (qtd == null || qtd <= 0) return null;
  final descricao = tokens.sublist(0, iQtd).join(' ').trim();
  if (descricao.length < 3 || !RegExp(r'[A-Za-zÀ-ÿ]{2,}').hasMatch(descricao)) {
    return null;
  }

  final dims = RegExp(r'(\d{3,4})\s*[xX×]\s*(\d{3,4})').firstMatch(descricao);
  final cat = categoria ?? inferirCategoria(descricao);
  return ItemLido(
    descricao: descricao,
    refFornecedor: ref,
    categoria: cat,
    quantidade: qtd,
    unidade: unidade.replaceAll('.', ''),
    larguraMm: dims != null ? double.parse(dims[1]!) : null,
    alturaMm: dims != null ? double.parse(dims[2]!) : null,
    espessuraMm: cat == CategoriaMaterial.chapa || cat == CategoriaMaterial.fita
        ? medidasMm(descricao).where((m) => m <= 60).firstOrNull
        : null,
  );
}

/// "18mm", "450mm", "35mm" no meio do nome não são quantidade.
bool _ehMedidaDeDescricao(String t) =>
    RegExp(r'^\d+(?:[.,]\d+)?(mm|cm)$', caseSensitive: false).hasMatch(t);

/// Unidade implícita de cada grupo, quando a linha só traz o número.
String? unidadeDoGrupo(CategoriaMaterial? c) => switch (c) {
  CategoriaMaterial.chapa || CategoriaMaterial.sobra => 'ch',
  CategoriaMaterial.fita => 'm',
  CategoriaMaterial.ferragem ||
  CategoriaMaterial.acessorio ||
  CategoriaMaterial.insumo => 'un',
  null => null,
};
