import '../models/enums.dart';
import 'arquivo_entrada.dart';

/// Item como veio do arquivo, antes de casar com o estoque.
class ItemLido {
  final String descricao;
  final String? refFornecedor;
  final String? fornecedorNome;
  final CategoriaMaterial? categoria;
  final double quantidade;

  /// Como veio: 'ch', 'un', 'm', 'm2', 'mm', 'pc', 'par'...
  final String unidade;
  final double? larguraMm;
  final double? alturaMm;
  final double? espessuraMm;
  final double? custoUnitario;

  const ItemLido({
    required this.descricao,
    this.refFornecedor,
    this.fornecedorNome,
    this.categoria,
    required this.quantidade,
    required this.unidade,
    this.larguraMm,
    this.alturaMm,
    this.espessuraMm,
    this.custoUnitario,
  });

  @override
  String toString() => '$descricao · $quantidade $unidade';
}

class ListaLida {
  final SoftwareLista software;
  final String? clienteNome;
  final String? projetoNome;
  final List<ItemLido> itens;

  /// 0–1, quão seguro o leitor está do resultado.
  final double confianca;
  final String textoExtraido;

  const ListaLida({
    required this.software,
    this.clienteNome,
    this.projetoNome,
    required this.itens,
    required this.confianca,
    required this.textoExtraido,
  });
}

abstract class LeitorLista {
  String get nome;

  /// 0 = não reconhece; 1 = certeza de que é o formato dele.
  Future<double> reconhece(ArquivoEntrada entrada);

  Future<ListaLida> ler(ArquivoEntrada entrada);
}
