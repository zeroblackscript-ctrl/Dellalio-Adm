import 'dart:convert';
import 'dart:typed_data';

import '../models/enums.dart';
import '../models/leitura.dart';
import 'arquivo_entrada.dart';
import 'canal_ia.dart';
import 'leitor.dart';

/// Último recurso: manda o arquivo ao Gemini e recebe o JSON no schema de
/// `ListaLida`. Lê qualquer PDF, inclusive escaneado sem texto.
class LeitorIA implements LeitorLista {
  LeitorIA({CanalIA? ia}) : _ia = ia;
  final CanalIA? _ia;

  @override
  String get nome => 'IA';

  /// Nota baixa de propósito: o importador sempre tenta a IA por último.
  @override
  Future<double> reconhece(ArquivoEntrada entrada) async =>
      entrada.ehPdf || entrada.ehPlanilha ? 0.1 : 0;

  @override
  Future<ListaLida> ler(ArquivoEntrada entrada) async {
    final (bytes, mime) = entrada.ehPdf
        ? (entrada.bytes, 'application/pdf')
        : (Uint8List.fromList(utf8.encode(entrada.texto)), 'text/plain');
    final r = await (_ia ?? CanalIA.padrao).lerLista(bytes, mime);
    return listaDoJson(r, entrada.texto);
  }

  static ListaLida listaDoJson(Map<String, dynamic> r, String texto) {
    final itens = lerListaMapas(r['itens'])
        .map((i) => ItemLido(
              descricao: lerTexto(i['descricao']) ?? '',
              refFornecedor: lerTexto(i['refFornecedor']),
              fornecedorNome: lerTexto(i['fornecedorNome']),
              categoria: CategoriaMaterial.tryFromName(lerTexto(i['categoria'])),
              quantidade: lerNum(i['quantidade']),
              unidade: lerTexto(i['unidade']) ?? 'un',
              larguraMm: lerNumOuNulo(i['larguraMm']),
              alturaMm: lerNumOuNulo(i['alturaMm']),
              espessuraMm: lerNumOuNulo(i['espessuraMm']),
              custoUnitario: lerNumOuNulo(i['custoUnitario']),
            ))
        .where((i) => i.descricao.isNotEmpty && i.quantidade > 0)
        .toList();
    return ListaLida(
      software: SoftwareLista.ia,
      clienteNome: lerTexto(r['clienteNome']),
      projetoNome: lerTexto(r['projetoNome']),
      itens: itens,
      confianca: itens.isEmpty ? 0 : 0.8,
      textoExtraido: texto,
    );
  }
}
