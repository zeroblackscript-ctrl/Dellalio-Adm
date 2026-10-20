import 'package:intl/intl.dart';

import '../models/enums.dart';
import 'normalizar.dart';

/// Arredonda pra unidade: inteiras (`ch`, `un`, `par`, `cx`) sempre pra
/// cima; as demais com 3 casas.
double arredondarParaUnidade(double q, UnidadeEstoque u) {
  if (q <= 0) return 0;
  if (u.inteira) return (q - 1e-9).ceilToDouble();
  return (q * 1000).roundToDouble() / 1000;
}

final NumberFormat _numero = NumberFormat('#,##0.##', 'pt_BR');
final NumberFormat _moeda = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
);

/// "14", "11,4", "1.250" — vírgula decimal.
String fmtNumero(double v) => _numero.format(v);

/// "14 ch", "212 m", "11,4 m²".
String fmtQtd(double v, UnidadeEstoque u) => '${fmtNumero(v)} ${u.sigla}';

/// "+5 ch", "−2 ch" (sinal de menos tipográfico, como nas telas).
String fmtQtdComSinal(double v, UnidadeEstoque u) {
  if (v > 0) return '+${fmtQtd(v, u)}';
  if (v < 0) return '−${fmtQtd(-v, u)}';
  return fmtQtd(0, u);
}

String fmtMoeda(double v) => _moeda.format(v);

/// Deduz a categoria pela descrição quando a fonte não diz.
CategoriaMaterial inferirCategoria(String descricao) {
  final t = tokens(descricao);
  final s = normalizar(descricao);
  bool tem(Iterable<String> ps) => ps.any((p) => t.contains(p));
  bool comeca(Iterable<String> ps) => ps.any((p) => t.any((x) => x.startsWith(p)));
  if (comeca(['sobra', 'retalho'])) return CategoriaMaterial.sobra;
  if (comeca(['fita', 'borda']) && !tem(['mdf', 'mdp'])) {
    return CategoriaMaterial.fita;
  }
  if (tem(['mdf', 'mdp', 'hdf', 'osb', 'compensado', 'chapa', 'painel']) ||
      s.contains('aglomerado')) {
    return CategoriaMaterial.chapa;
  }
  if (comeca([
    'dobradi', 'dob', 'corredi', 'trilho', 'puxador', 'fechadura', //
    'pistao', 'articulador', 'suporte', 'cantoneira', 'rodizio',
  ])) {
    return CategoriaMaterial.ferragem;
  }
  if (comeca(['parafuso', 'cola', 'prego', 'cavilha', 'lixa', 'silicone', 'adesivo', 'tapa', 'bucha'])) {
    return CategoriaMaterial.insumo;
  }
  return CategoriaMaterial.acessorio;
}

/// Unidade de estoque padrão de cada categoria, pra material criado sozinho.
UnidadeEstoque unidadePadrao(CategoriaMaterial c) => switch (c) {
  CategoriaMaterial.chapa || CategoriaMaterial.sobra => UnidadeEstoque.ch,
  CategoriaMaterial.fita => UnidadeEstoque.m,
  _ => UnidadeEstoque.un,
};
