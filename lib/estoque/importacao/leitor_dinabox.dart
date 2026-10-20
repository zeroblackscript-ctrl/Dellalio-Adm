import '../models/enums.dart';
import '../util/normalizar.dart';
import 'arquivo_entrada.dart';
import 'leitor.dart';
import 'leitor_planilha.dart';
import 'parser_linha.dart';

/// Leitor principal: "Lista de Compras" do DinaBox (plugin do SketchUp), em
/// PDF de texto ou exportada como planilha.
///
/// Ainda não temos um arquivo real, então o parser é tolerante e os pontos
/// que dependem do layout exato estão marcados com `TODO(arquivo-real)`.
/// O `textoExtraido` de toda lista fica salvo pra afinar isto depois.
class LeitorDinabox implements LeitorLista {
  @override
  String get nome => 'DinaBox';

  static bool temMarcador(ArquivoEntrada e) {
    final inicio = e.texto.length > 4000 ? e.texto.substring(0, 4000) : e.texto;
    // TODO(arquivo-real): confirmar como o DinaBox se identifica no PDF.
    return normalizar('${e.metadados} $inicio').contains('dinabox');
  }

  @override
  Future<double> reconhece(ArquivoEntrada entrada) async {
    if (!entrada.ehPdf && !entrada.ehPlanilha) return 0;
    final marcador = temMarcador(entrada);
    var nota = marcador ? 0.6 : 0.0;
    final t = normalizar(entrada.texto);
    if (t.contains('lista de compras') || t.contains('lista de materiais')) {
      nota += 0.2;
    }
    final grupos = entrada.linhas.where((l) => categoriaDoCabecalho(l) != null).length;
    nota += (grupos * 0.07).clamp(0, 0.2);
    // Sem o marcador fica abaixo da planilha genérica: grupos de marcenaria
    // sozinhos não provam que é DinaBox.
    if (!marcador) nota = nota.clamp(0, 0.35);
    return nota.clamp(0, 1).toDouble();
  }

  @override
  Future<ListaLida> ler(ArquivoEntrada entrada) async {
    if (entrada.ehPlanilha) {
      // Mesma detecção de cabeçalho da planilha genérica, marcada DinaBox.
      final lida = await LeitorPlanilha().ler(entrada);
      return ListaLida(
        software: SoftwareLista.dinabox,
        clienteNome: lida.clienteNome,
        projetoNome: lida.projetoNome,
        itens: lida.itens,
        confianca: lida.confianca,
        textoExtraido: lida.textoExtraido,
      );
    }
    return lerTexto(entrada.texto, marcador: temMarcador(entrada));
  }

  /// Parser por linhas, separado pra ser testado com texto simulado.
  static ListaLida lerTexto(String texto, {bool marcador = true}) {
    final linhas = texto.split(RegExp(r'\r?\n'));
    final itens = <ItemLido>[];
    CategoriaMaterial? grupo;
    var candidatas = 0;

    for (final bruta in linhas) {
      final linha = bruta.trim();
      if (linha.isEmpty) continue;
      final cab = categoriaDoCabecalho(linha);
      if (cab != null) {
        grupo = cab;
        continue;
      }
      if (linhaIgnorada(linha)) continue;
      if (!RegExp(r'\d').hasMatch(linha) ||
          !RegExp(r'[A-Za-zÀ-ÿ]{2,}').hasMatch(linha)) {
        continue;
      }
      candidatas++;
      // TODO(arquivo-real): se o DinaBox listar peças cortadas antes dos
      // totais por material, pular a seção de peças aqui.
      final item = itemDaLinha(
        linha,
        categoria: grupo,
        unidadePadrao: unidadeDoGrupo(grupo),
      );
      if (item != null) itens.add(item);
    }

    final cobertura = candidatas == 0 ? 0.0 : itens.length / candidatas;
    final base = marcador ? 0.6 : 0.45;
    return ListaLida(
      software: SoftwareLista.dinabox,
      // TODO(arquivo-real): confirmar os rótulos do cabeçalho do DinaBox.
      clienteNome: campoCabecalho(linhas, const ['cliente', 'nome do cliente']),
      projetoNome: campoCabecalho(
        linhas,
        const ['projeto', 'ambiente', 'obra', 'nome do projeto'],
      ),
      itens: itens,
      confianca: itens.isEmpty ? 0 : (base + 0.35 * cobertura).clamp(0, 0.95),
      textoExtraido: texto,
    );
  }
}
