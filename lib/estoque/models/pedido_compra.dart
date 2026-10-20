import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'leitura.dart';

class ItemPedido {
  final String materialId;
  final String nome;
  final String? refFornecedor;
  final double quantidade;
  final UnidadeEstoque unidade;
  final OrigemItemPedido origem;
  final List<String> listaCorteIds;

  /// Quanto de [quantidade] veio de cada lista — pra cancelar uma lista e
  /// tirar do rascunho só o que era dela.
  final Map<String, double> porLista;

  /// Parte da quantidade que veio de reposição de mínimo.
  final double qtdMinimo;
  final double qtdRecebida;

  /// "Cozinha Rodrigues", "repor mínimo"... desnormalizado pra tela.
  final List<String> destinos;

  const ItemPedido({
    required this.materialId,
    required this.nome,
    this.refFornecedor,
    required this.quantidade,
    required this.unidade,
    required this.origem,
    this.listaCorteIds = const [],
    this.porLista = const {},
    this.qtdMinimo = 0,
    this.qtdRecebida = 0,
    this.destinos = const [],
  });

  factory ItemPedido.fromMap(Map<String, dynamic> d) => ItemPedido(
    materialId: lerTexto(d['materialId']) ?? '',
    nome: lerTexto(d['nome']) ?? '',
    refFornecedor: lerTexto(d['refFornecedor']),
    quantidade: lerNum(d['quantidade']),
    unidade: UnidadeEstoque.fromName(d['unidade'] as String?),
    origem: OrigemItemPedido.fromName(d['origem'] as String?),
    listaCorteIds: lerListaTexto(d['listaCorteIds']),
    porLista: lerMapaNum(d['porLista']),
    qtdMinimo: lerNum(d['qtdMinimo']),
    qtdRecebida: lerNum(d['qtdRecebida']),
    destinos: lerListaTexto(d['destinos']),
  );

  Map<String, dynamic> toMap() => semNulos({
    'materialId': materialId,
    'nome': nome,
    'refFornecedor': refFornecedor,
    'quantidade': quantidade,
    'unidade': unidade.name,
    'origem': origem.name,
    'listaCorteIds': listaCorteIds,
    'porLista': porLista,
    'qtdMinimo': qtdMinimo,
    'qtdRecebida': qtdRecebida,
    'destinos': destinos,
  });

  ItemPedido copyWith({
    double? quantidade,
    OrigemItemPedido? origem,
    List<String>? listaCorteIds,
    Map<String, double>? porLista,
    double? qtdMinimo,
    double? qtdRecebida,
    List<String>? destinos,
    String? refFornecedor,
  }) {
    return ItemPedido(
      materialId: materialId,
      nome: nome,
      refFornecedor: refFornecedor ?? this.refFornecedor,
      quantidade: quantidade ?? this.quantidade,
      unidade: unidade,
      origem: origem ?? this.origem,
      listaCorteIds: listaCorteIds ?? this.listaCorteIds,
      porLista: porLista ?? this.porLista,
      qtdMinimo: qtdMinimo ?? this.qtdMinimo,
      qtdRecebida: qtdRecebida ?? this.qtdRecebida,
      destinos: destinos ?? this.destinos,
    );
  }
}

/// Documento de `pedidos_compra/{id}`. No máximo um `rascunho` por
/// fornecedor; material sem fornecedor cai no rascunho com
/// `fornecedorId == null` ("Sem fornecedor definido").
class PedidoCompra {
  final String id;
  final String? fornecedorId;
  final String fornecedorNome;
  final StatusPedido status;
  final List<ItemPedido> itens;
  final DateTime? criadoEm;
  final DateTime? enviadoEm;
  final DateTime? recebidoEm;

  const PedidoCompra({
    required this.id,
    this.fornecedorId,
    required this.fornecedorNome,
    required this.status,
    this.itens = const [],
    this.criadoEm,
    this.enviadoEm,
    this.recebidoEm,
  });

  static const String semFornecedorNome = 'Sem fornecedor definido';

  bool get semFornecedor => fornecedorId == null;

  factory PedidoCompra.fromMap(String id, Map<String, dynamic> d) =>
      PedidoCompra(
        id: id,
        fornecedorId: lerTexto(d['fornecedorId']),
        fornecedorNome: lerTexto(d['fornecedorNome']) ?? semFornecedorNome,
        status: StatusPedido.fromName(d['status'] as String?),
        itens: lerListaMapas(d['itens']).map(ItemPedido.fromMap).toList(),
        criadoEm: lerData(d['criadoEm']),
        enviadoEm: lerData(d['enviadoEm']),
        recebidoEm: lerData(d['recebidoEm']),
      );

  factory PedidoCompra.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      PedidoCompra.fromMap(doc.id, doc.data() ?? const {});

  /// `fornecedorId` vai sempre (mesmo nulo) pra consulta por rascunho
  /// "sem fornecedor" funcionar com `isNull`.
  Map<String, dynamic> toMap() => {
    'fornecedorId': fornecedorId,
    'fornecedorNome': fornecedorNome,
    'status': status.name,
    'itens': itens.map((i) => i.toMap()).toList(),
  };

  PedidoCompra copyWith({
    StatusPedido? status,
    List<ItemPedido>? itens,
    String? fornecedorId,
    String? fornecedorNome,
  }) {
    return PedidoCompra(
      id: id,
      fornecedorId: fornecedorId ?? this.fornecedorId,
      fornecedorNome: fornecedorNome ?? this.fornecedorNome,
      status: status ?? this.status,
      itens: itens ?? this.itens,
      criadoEm: criadoEm,
      enviadoEm: enviadoEm,
      recebidoEm: recebidoEm,
    );
  }
}
