import '../models/enums.dart';
import 'arquivo_entrada.dart';
import 'leitor.dart';
import 'parser_linha.dart';

/// PDF de texto sem marcador conhecido: linha com texto descritivo + número
/// + unidade conhecida. Confiança sempre ≤ 0,6, então normalmente quem
/// resolve é a IA; o resultado daqui fica de reserva se a IA falhar.
class LeitorGenerico implements LeitorLista {
  @override
  String get nome => 'Genérico';

  @override
  Future<double> reconhece(ArquivoEntrada entrada) async =>
      entrada.ehPdf && !entrada.pdfSemTexto ? 0.3 : 0;

  @override
  Future<ListaLida> ler(ArquivoEntrada entrada) async {
    final linhas = entrada.linhas;
    final itens = <ItemLido>[];
    CategoriaMaterial? grupo;
    var candidatas = 0;
    for (final bruta in linhas) {
      final linha = bruta.trim();
      grupo = categoriaDoCabecalho(linha) ?? grupo;
      if (linhaIgnorada(linha) || !RegExp(r'\d').hasMatch(linha)) continue;
      candidatas++;
      // Exige unidade explícita: sem o grupo do DinaBox, número solto é
      // arriscado demais.
      final item = itemDaLinha(linha, categoria: grupo);
      if (item != null) itens.add(item);
    }
    final cobertura = candidatas == 0 ? 0.0 : itens.length / candidatas;
    return ListaLida(
      software: SoftwareLista.generico,
      clienteNome: campoCabecalho(linhas, const ['cliente']),
      projetoNome: campoCabecalho(linhas, const ['projeto', 'ambiente', 'obra']),
      itens: itens,
      confianca: itens.isEmpty ? 0 : 0.35 + 0.25 * cobertura,
      textoExtraido: entrada.texto,
    );
  }
}
