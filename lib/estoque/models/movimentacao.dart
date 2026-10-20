import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'leitura.dart';

/// Documento imutável de `movimentacoes/{id}`. Nunca editar nem apagar:
/// correção é uma nova movimentação `ajuste`.
class Movimentacao {
  final String id;
  final String materialId;
  final String materialNome;
  final TipoMovimentacao tipo;

  /// Sempre positiva; o [tipo] (e o [sinal], no ajuste) define o sentido.
  final double quantidade;

  /// +1 ou −1. Só faz diferença no `ajuste`.
  final int sinal;
  final UnidadeEstoque unidade;
  final String motivo;
  final String? clienteNome;
  final String? projetoNome;
  final String? fornecedorNome;
  final String? listaCorteId;
  final String? notaFiscalId;
  final String? pedidoId;
  final OrigemMovimentacao origem;
  final String responsavelId;
  final String responsavelNome;
  final double fisicoAntes;
  final double fisicoDepois;
  final double reservadoAntes;
  final double reservadoDepois;
  final DateTime? criadoEm;

  const Movimentacao({
    required this.id,
    required this.materialId,
    required this.materialNome,
    required this.tipo,
    required this.quantidade,
    this.sinal = 1,
    required this.unidade,
    required this.motivo,
    this.clienteNome,
    this.projetoNome,
    this.fornecedorNome,
    this.listaCorteId,
    this.notaFiscalId,
    this.pedidoId,
    required this.origem,
    required this.responsavelId,
    required this.responsavelNome,
    required this.fisicoAntes,
    required this.fisicoDepois,
    required this.reservadoAntes,
    required this.reservadoDepois,
    this.criadoEm,
  });

  /// Quantidade com sinal pra exibir no histórico: entrada soma, saída e
  /// perda tiram, reserva/liberação mexem só no reservado.
  double get quantidadeComSinal => switch (tipo) {
    TipoMovimentacao.entrada => quantidade,
    TipoMovimentacao.saida || TipoMovimentacao.perda => -quantidade,
    TipoMovimentacao.reserva => quantidade,
    TipoMovimentacao.liberacaoReserva => -quantidade,
    TipoMovimentacao.ajuste => quantidade * sinal,
  };

  /// "Cozinha · Rodrigues" quando houver projeto/cliente.
  String? get paraQuem {
    final partes = [projetoNome, clienteNome].whereType<String>().toList();
    return partes.isEmpty ? null : partes.join(' · ');
  }

  factory Movimentacao.fromMap(String id, Map<String, dynamic> d) {
    return Movimentacao(
      id: id,
      materialId: lerTexto(d['materialId']) ?? '',
      materialNome: lerTexto(d['materialNome']) ?? '',
      tipo: TipoMovimentacao.fromName(d['tipo'] as String?),
      quantidade: lerNum(d['quantidade']),
      sinal: lerNum(d['sinal'], 1) < 0 ? -1 : 1,
      unidade: UnidadeEstoque.fromName(d['unidade'] as String?),
      motivo: lerTexto(d['motivo']) ?? '',
      clienteNome: lerTexto(d['clienteNome']),
      projetoNome: lerTexto(d['projetoNome']),
      fornecedorNome: lerTexto(d['fornecedorNome']),
      listaCorteId: lerTexto(d['listaCorteId']),
      notaFiscalId: lerTexto(d['notaFiscalId']),
      pedidoId: lerTexto(d['pedidoId']),
      origem: OrigemMovimentacao.fromName(d['origem'] as String?),
      responsavelId: lerTexto(d['responsavelId']) ?? 'sistema',
      responsavelNome: lerTexto(d['responsavelNome']) ?? 'Sistema',
      fisicoAntes: lerNum(d['fisicoAntes']),
      fisicoDepois: lerNum(d['fisicoDepois']),
      reservadoAntes: lerNum(d['reservadoAntes']),
      reservadoDepois: lerNum(d['reservadoDepois']),
      criadoEm: lerData(d['criadoEm']),
    );
  }

  factory Movimentacao.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Movimentacao.fromMap(doc.id, doc.data() ?? const {});

  /// Sem `criadoEm`: quem grava usa `FieldValue.serverTimestamp()`.
  Map<String, dynamic> toMap() => semNulos({
    'materialId': materialId,
    'materialNome': materialNome,
    'tipo': tipo.name,
    'quantidade': quantidade,
    'sinal': sinal,
    'unidade': unidade.name,
    'motivo': motivo,
    'clienteNome': clienteNome,
    'projetoNome': projetoNome,
    'fornecedorNome': fornecedorNome,
    'listaCorteId': listaCorteId,
    'notaFiscalId': notaFiscalId,
    'pedidoId': pedidoId,
    'origem': origem.name,
    'responsavelId': responsavelId,
    'responsavelNome': responsavelNome,
    'fisicoAntes': fisicoAntes,
    'fisicoDepois': fisicoDepois,
    'reservadoAntes': reservadoAntes,
    'reservadoDepois': reservadoDepois,
  });

  Movimentacao copyWith({
    String? id,
    double? quantidade,
    int? sinal,
    String? motivo,
    DateTime? criadoEm,
  }) {
    return Movimentacao(
      id: id ?? this.id,
      materialId: materialId,
      materialNome: materialNome,
      tipo: tipo,
      quantidade: quantidade ?? this.quantidade,
      sinal: sinal ?? this.sinal,
      unidade: unidade,
      motivo: motivo ?? this.motivo,
      clienteNome: clienteNome,
      projetoNome: projetoNome,
      fornecedorNome: fornecedorNome,
      listaCorteId: listaCorteId,
      notaFiscalId: notaFiscalId,
      pedidoId: pedidoId,
      origem: origem,
      responsavelId: responsavelId,
      responsavelNome: responsavelNome,
      fisicoAntes: fisicoAntes,
      fisicoDepois: fisicoDepois,
      reservadoAntes: reservadoAntes,
      reservadoDepois: reservadoDepois,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }
}
