import '../models/models.dart';
import '../util/normalizar.dart';

/// O que o casamento sabe de um item (de lista ou de nota).
class AlvoCasamento {
  final String descricao;
  final String? refFornecedor;
  final CategoriaMaterial? categoria;
  final double? espessuraMm;
  final String? fornecedorId;

  const AlvoCasamento({
    required this.descricao,
    this.refFornecedor,
    this.categoria,
    this.espessuraMm,
    this.fornecedorId,
  });
}

class Candidato {
  final MaterialEstoque material;
  final double score;
  const Candidato(this.material, this.score);
}

/// Palavras de "tipo" (genéricas): pesam menos que cor/padrão, que é o que
/// de fato diferencia duas chapas.
const Set<String> _palavrasDeTipo = {
  'mdf', 'mdp', 'hdf', 'osb', 'chapa', 'chapas', 'painel', 'compensado',
  'fita', 'borda', 'bordas', 'dobradica', 'dobradicas', 'corredica',
  'corredicas', 'puxador', 'puxadores', 'parafuso', 'parafusos', 'cola',
  'telescopica', 'telesc', 'reta', 'curva', 'super', 'ultra', 'perfil',
  'aluminio', 'aco', 'pvc', 'abs', 'tx', 'bp', 'ff', 'face', 'faces',
  'dupla', 'simples', 'acabamento', 'un', 'pc', 'cx', 'kit', 'jogo', 'par',
};

double _peso(String t) {
  if (RegExp(r'\d').hasMatch(t)) return 1;
  if (_palavrasDeTipo.contains(t)) return 1;
  return 2; // cor/padrão/qualificador: "louro", "freijo", "cinza", "cristal"
}

/// Tokens equivalentes: iguais, um é prefixo do outro (≥3 letras: "dob" ↔
/// "dobradica", "amort" ↔ "amortecedor") ou o mesmo número com/sem unidade
/// ("35" ↔ "35mm").
bool _equivalentes(String a, String b) {
  if (a == b) return true;
  final na = RegExp(r'^(\d+(?:\.\d+)?)(mm|cm|m)?$').firstMatch(a);
  final nb = RegExp(r'^(\d+(?:\.\d+)?)(mm|cm|m)?$').firstMatch(b);
  if (na != null && nb != null) return na[1] == nb[1];
  if (na != null || nb != null) return false;
  final (curto, longo) = a.length <= b.length ? (a, b) : (b, a);
  return curto.length >= 3 && longo.startsWith(curto);
}

/// Similaridade ponderada de tokens (Jaccard com casamento por prefixo).
double similaridadeTokens(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final usados = <String>{};
  var comum = 0.0;
  for (final ta in a) {
    for (final tb in b) {
      if (!usados.contains(tb) && _equivalentes(ta, tb)) {
        usados.add(tb);
        comum += (_peso(ta) + _peso(tb)) / 2;
        break;
      }
    }
  }
  final total = a.fold<double>(0, (s, t) => s + _peso(t)) +
      b.fold<double>(0, (s, t) => s + _peso(t)) -
      comum;
  return total <= 0 ? 0 : comum / total;
}

/// Score 0–1 do [alvo] contra um material.
/// - Espessura diferente zera (MDF 15 mm nunca casa com 18 mm).
/// - Medidas em mm do texto (ex.: `450mm` de corrediça) têm de bater.
/// - Fornecedor igual dá um pequeno bônus.
double scoreCasamento(AlvoCasamento alvo, MaterialEstoque m) {
  final medidasAlvo = {
    ...medidasMm(alvo.descricao),
    ?alvo.espessuraMm,
  };
  final medidasMat = {
    ...medidasMm(m.nome),
    ?m.espessuraMm,
  };
  if (alvo.espessuraMm != null &&
      m.espessuraMm != null &&
      alvo.espessuraMm != m.espessuraMm) {
    return 0;
  }
  if (medidasAlvo.isNotEmpty &&
      medidasMat.isNotEmpty &&
      medidasAlvo.intersection(medidasMat).isEmpty) {
    return 0;
  }

  final ta = tokens(alvo.descricao);
  var melhor = similaridadeTokens(ta, tokens(m.nome));
  for (final ap in m.apelidos) {
    final s = similaridadeTokens(ta, tokens(ap));
    if (s > melhor) melhor = s;
  }
  if (alvo.fornecedorId != null && alvo.fornecedorId == m.fornecedorId) {
    melhor += 0.05;
  }
  return melhor.clamp(0, 1).toDouble();
}

/// Melhores candidatos, do maior score pro menor. Compara primeiro com a
/// mesma categoria; se nada lá passar de 0,6, olha as outras com um
/// pequeno desconto (categoria deduzida pode estar errada).
List<Candidato> rankear(
  AlvoCasamento alvo,
  Iterable<MaterialEstoque> materiais, {
  int limite = 5,
}) {
  final ativos = materiais.where((m) => m.ativo).toList();
  List<Candidato> pontuar(Iterable<MaterialEstoque> ms, double fator) => [
    for (final m in ms)
      if (scoreCasamento(alvo, m) * fator case final s when s > 0)
        Candidato(m, s),
  ]..sort((a, b) => b.score.compareTo(a.score));

  var lista = alvo.categoria == null
      ? pontuar(ativos, 1)
      : pontuar(ativos.where((m) => m.categoria == alvo.categoria), 1);
  if (alvo.categoria != null && (lista.isEmpty || lista.first.score < 0.6)) {
    lista = [
      ...lista,
      ...pontuar(ativos.where((m) => m.categoria != alvo.categoria), 0.9),
    ]..sort((a, b) => b.score.compareTo(a.score));
  }
  return lista.take(limite).toList();
}

/// Passos 1 e 2 do casamento: referência e apelido (exatos).
MaterialEstoque? porReferencia(String? ref, Iterable<MaterialEstoque> ms) {
  if (ref == null || ref.trim().isEmpty) return null;
  final r = normalizar(ref);
  return ms.where((m) => m.ativo && m.refFornecedor != null && normalizar(m.refFornecedor!) == r).firstOrNull;
}

MaterialEstoque? porApelido(String descricao, Iterable<MaterialEstoque> ms) {
  final d = normalizar(descricao);
  return ms
      .where((m) => m.ativo && (m.apelidos.contains(d) || normalizar(m.nome) == d))
      .firstOrNull;
}
