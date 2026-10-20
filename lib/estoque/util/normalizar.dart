/// Normalização de texto usada em apelidos, buscas e casamento de materiais
/// (regra 5 do contexto): minúsculas, sem acento, `18 mm`/`18MM` → `18mm`,
/// `x`/`X`/`×` entre números → `x`, pontuação vira espaço e espaços
/// colapsados. Vírgula/ponto decimal entre dígitos vira `.` (`1,5 mm` →
/// `1.5mm`) pra não partir a medida em dois tokens.
library;

const Map<String, String> _semAcento = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n', '²': '2', '³': '3', '×': 'x', 'º': 'o', 'ª': 'a',
};

final RegExp _decimal = RegExp(r'(\d)[.,](\d)');
final RegExp _naoPermitido = RegExp(r'[^a-z0-9.\s]');
final RegExp _pontoSolto = RegExp(r'(?<!\d)\.|\.(?!\d)');
final RegExp _numeroUnidade = RegExp(
  r'(\d)\s+(mm|cm|m2|m3|m|kg|g|ml|l)(?![a-z0-9])',
);
final RegExp _vezes = RegExp(r'(\d(?:mm|cm|m)?)\s*x\s*(?=\d)');
final RegExp _espacos = RegExp(r'\s+');

String normalizar(String texto) {
  var s = texto.toLowerCase();
  final b = StringBuffer();
  for (final rune in s.runes) {
    final c = String.fromCharCode(rune);
    b.write(_semAcento[c] ?? c);
  }
  s = b.toString();
  s = s.replaceAllMapped(_decimal, (m) => '${m[1]}.${m[2]}');
  s = s.replaceAll(_naoPermitido, ' ');
  s = s.replaceAll(_pontoSolto, ' ');
  s = s.replaceAllMapped(_numeroUnidade, (m) => '${m[1]}${m[2]}');
  s = s.replaceAllMapped(_vezes, (m) => '${m[1]}x');
  return s.replaceAll(_espacos, ' ').trim();
}

/// Palavras que não ajudam a diferenciar materiais.
const Set<String> _vazias = {
  'de', 'da', 'do', 'das', 'dos', 'e', 'com', 'c', 'p', 'para', 'em', //
  'a', 'o', 'na', 'no',
};

/// Tokens normalizados de [texto], sem palavras vazias.
Set<String> tokens(String texto) => normalizar(
  texto,
).split(' ').where((t) => t.isNotEmpty && !_vazias.contains(t)).toSet();

final RegExp _espessura = RegExp(r'(?<![\dx.])(\d+(?:\.\d+)?)mm(?![\dx])');

/// Medidas em mm presentes no texto (ex.: `18mm`, `450mm`), já normalizadas.
/// Usado pelo casamento: medida diferente nunca casa.
Set<double> medidasMm(String texto) => _espessura
    .allMatches(normalizar(texto))
    .map((m) => double.parse(m[1]!))
    .toSet();

/// Nome legível para um material criado a partir de uma descrição crua de
/// lista ou nota. Descrições em CAIXA ALTA viram "Título", mantendo siglas
/// de marcenaria em maiúsculas e medidas em minúsculas.
String nomeLegivel(String descricao) {
  final limpa = descricao.trim().replaceAll(_espacos, ' ');
  final letras = limpa.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
  if (letras.isEmpty) return limpa;
  final maiusculas = letras.split('').where((c) => c != c.toLowerCase());
  if (maiusculas.length < letras.length * 0.7) return limpa;
  const siglas = {'mdf', 'mdp', 'hdf', 'osb', 'pvc', 'abs', 'tx', 'bp', 'ldf'};
  return limpa
      .split(' ')
      .map((p) {
        final baixa = p.toLowerCase();
        if (siglas.contains(baixa)) return p.toUpperCase();
        if (RegExp(r'\d').hasMatch(p)) return baixa;
        return baixa.isEmpty
            ? baixa
            : baixa[0].toUpperCase() + baixa.substring(1);
      })
      .join(' ');
}
