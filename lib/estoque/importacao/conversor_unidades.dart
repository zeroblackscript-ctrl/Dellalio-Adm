import '../models/models.dart';
import '../util/normalizar.dart';
import '../util/quantidade.dart';

/// Unidade de origem já padronizada.
enum UnidadeLida { ch, m2, m, un, par, kg, l, cx, pct, desconhecida }

/// Lê a unidade como veio ("chapas", "m²", "pç", "metro linear", "mm"...)
/// e devolve a unidade padronizada e o fator pra chegar nela
/// (mm → m é ÷1000; g → kg é ÷1000).
(UnidadeLida, double) padronizarUnidade(String bruta) {
  final u = normalizar(bruta).replaceAll(' ', '');
  const tabela = <String, (UnidadeLida, double)>{
    'ch': (UnidadeLida.ch, 1), 'chs': (UnidadeLida.ch, 1), //
    'chapa': (UnidadeLida.ch, 1), 'chapas': (UnidadeLida.ch, 1),
    'chp': (UnidadeLida.ch, 1), 'placa': (UnidadeLida.ch, 1),
    'placas': (UnidadeLida.ch, 1), 'folha': (UnidadeLida.ch, 1),
    'folhas': (UnidadeLida.ch, 1), 'painel': (UnidadeLida.ch, 1),
    'm2': (UnidadeLida.m2, 1), 'mt2': (UnidadeLida.m2, 1),
    'mq': (UnidadeLida.m2, 1), 'metroquadrado': (UnidadeLida.m2, 1),
    'metrosquadrados': (UnidadeLida.m2, 1),
    'm': (UnidadeLida.m, 1), 'mt': (UnidadeLida.m, 1), 'mts': (UnidadeLida.m, 1),
    'metro': (UnidadeLida.m, 1), 'metros': (UnidadeLida.m, 1),
    'ml': (UnidadeLida.m, 1), 'mlinear': (UnidadeLida.m, 1),
    'metrolinear': (UnidadeLida.m, 1), 'metroslineares': (UnidadeLida.m, 1),
    'mm': (UnidadeLida.m, 0.001), 'cm': (UnidadeLida.m, 0.01),
    'un': (UnidadeLida.un, 1), 'und': (UnidadeLida.un, 1),
    'unid': (UnidadeLida.un, 1), 'unidade': (UnidadeLida.un, 1),
    'unidades': (UnidadeLida.un, 1), 'u': (UnidadeLida.un, 1),
    'pc': (UnidadeLida.un, 1), 'pcs': (UnidadeLida.un, 1),
    'peca': (UnidadeLida.un, 1), 'pecas': (UnidadeLida.un, 1),
    'pca': (UnidadeLida.un, 1),
    'par': (UnidadeLida.par, 1), 'pares': (UnidadeLida.par, 1),
    'pr': (UnidadeLida.par, 1), 'jogo': (UnidadeLida.par, 1),
    'kg': (UnidadeLida.kg, 1), 'g': (UnidadeLida.kg, 0.001),
    'l': (UnidadeLida.l, 1), 'lt': (UnidadeLida.l, 1),
    'litro': (UnidadeLida.l, 1), 'litros': (UnidadeLida.l, 1),
    'cx': (UnidadeLida.cx, 1), 'caixa': (UnidadeLida.cx, 1),
    'caixas': (UnidadeLida.cx, 1),
    'pct': (UnidadeLida.pct, 1), 'pacote': (UnidadeLida.pct, 1),
    'pacotes': (UnidadeLida.pct, 1),
  };
  return tabela[u] ?? (UnidadeLida.desconhecida, 1);
}

/// Unidade de estoque correspondente, quando existe uma direta.
UnidadeEstoque? unidadeEstoqueDe(UnidadeLida u) => switch (u) {
  UnidadeLida.ch => UnidadeEstoque.ch,
  UnidadeLida.m2 => UnidadeEstoque.m2,
  UnidadeLida.m => UnidadeEstoque.m,
  UnidadeLida.un => UnidadeEstoque.un,
  UnidadeLida.par => UnidadeEstoque.par,
  UnidadeLida.kg => UnidadeEstoque.kg,
  UnidadeLida.l => UnidadeEstoque.l,
  UnidadeLida.cx => UnidadeEstoque.cx,
  UnidadeLida.pct || UnidadeLida.desconhecida => null,
};

/// Unidade-palavra reconhecida? (usado pelos parsers de linha)
bool ehUnidade(String token) =>
    padronizarUnidade(token).$1 != UnidadeLida.desconhecida;

class Conversao {
  final double quantidade;
  final UnidadeEstoque unidade;

  /// Usou a chapa padrão (sem medida no material nem no item): conferir.
  final bool conferir;

  /// Não sei converter: o item vai pra "confirmar".
  final bool desconhecida;

  /// "veio como 11,4 m² → 3 chapas".
  final String? observacao;

  const Conversao({
    required this.quantidade,
    required this.unidade,
    this.conferir = false,
    this.desconhecida = false,
    this.observacao,
  });
}

/// Chapa padrão de MDF pra converter m² quando não há medida (configurável).
class ChapaPadrao {
  static double larguraMm = 2750;
  static double alturaMm = 1850;
}

class ConversorUnidades {
  /// Converte a quantidade lida pra unidade de estoque do [material].
  static Conversao paraUnidadeDoEstoque({
    required double quantidade,
    required String unidadeOriginal,
    double? larguraItemMm,
    double? alturaItemMm,
    required MaterialEstoque material,
  }) {
    final (lida, fator) = padronizarUnidade(unidadeOriginal);
    final q = quantidade * fator;
    final alvo = material.unidade;
    Conversao ok(double v, {bool conferir = false, String? obs}) => Conversao(
      quantidade: arredondarParaUnidade(v, alvo),
      unidade: alvo,
      conferir: conferir,
      observacao: obs,
    );

    if (unidadeEstoqueDe(lida) == alvo) return ok(q);

    // m² ↔ chapa, pela medida do material, do item ou da chapa padrão.
    if (lida == UnidadeLida.m2 && alvo == UnidadeEstoque.ch ||
        lida == UnidadeLida.ch && alvo == UnidadeEstoque.m2) {
      final (larg, alt, padrao) = _medidaChapa(material, larguraItemMm, alturaItemMm);
      final area = larg * alt / 1e6;
      if (lida == UnidadeLida.m2) {
        final chapas = arredondarParaUnidade(q / area, UnidadeEstoque.ch);
        return ok(
          chapas,
          conferir: padrao,
          obs: 'veio como ${fmtNumero(q)} m² → ${fmtNumero(chapas)} '
              '${chapas == 1 ? 'chapa' : 'chapas'}'
              '${padrao ? ' (chapa padrão ${larg.toInt()}×${alt.toInt()})' : ''}',
        );
      }
      return ok(q * area, conferir: padrao);
    }

    if (lida == UnidadeLida.par && alvo == UnidadeEstoque.un) {
      return ok(q * 2, obs: 'veio como ${fmtNumero(q)} par → ${fmtNumero(q * 2)} un');
    }
    if (lida == UnidadeLida.un && alvo == UnidadeEstoque.par) {
      return ok(q / 2, conferir: true, obs: 'veio como ${fmtNumero(q)} un');
    }

    // Embalagem com fator aprendido (CX → 100 un).
    if (lida == UnidadeLida.cx || lida == UnidadeLida.pct) {
      final chave = lida == UnidadeLida.cx ? 'CX' : 'PCT';
      final f = material.fatorEmbalagem[chave];
      if (f != null && f > 0) {
        return ok(q * f, obs: 'veio como ${fmtNumero(q)} $chave');
      }
    }

    return Conversao(
      quantidade: q,
      unidade: alvo,
      desconhecida: true,
      observacao: 'veio como ${fmtNumero(quantidade)} $unidadeOriginal',
    );
  }

  static (double, double, bool) _medidaChapa(
    MaterialEstoque m,
    double? largItem,
    double? altItem,
  ) {
    if ((m.larguraMm ?? 0) > 0 && (m.alturaMm ?? 0) > 0) {
      return (m.larguraMm!, m.alturaMm!, false);
    }
    if ((largItem ?? 0) > 0 && (altItem ?? 0) > 0) {
      return (largItem!, altItem!, false);
    }
    return (ChapaPadrao.larguraMm, ChapaPadrao.alturaMm, true);
  }

  /// Unidade com que nasce um material criado a partir de um item lido.
  static UnidadeEstoque unidadeParaNovo(String unidadeOriginal, CategoriaMaterial c) {
    if (c == CategoriaMaterial.chapa || c == CategoriaMaterial.sobra) {
      return UnidadeEstoque.ch;
    }
    final u = unidadeEstoqueDe(padronizarUnidade(unidadeOriginal).$1);
    if (u == null || u == UnidadeEstoque.m2) return unidadePadrao(c);
    return u;
  }
}
