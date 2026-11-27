import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'leitura.dart';

/// Linha do comprovante: o que saiu/entrou e o saldo físico antes e depois.
class ItemComprovante {
  final String materialId;
  final String materialNome;
  final double quantidade;
  final UnidadeEstoque unidade;
  final String? local;
  final double fisicoAntes;
  final double fisicoDepois;
  final String? movimentacaoId;

  const ItemComprovante({
    required this.materialId,
    required this.materialNome,
    required this.quantidade,
    required this.unidade,
    this.local,
    this.fisicoAntes = 0,
    this.fisicoDepois = 0,
    this.movimentacaoId,
  });

  factory ItemComprovante.fromMap(Map<String, dynamic> d) => ItemComprovante(
    materialId: lerTexto(d['materialId']) ?? '',
    materialNome: lerTexto(d['materialNome']) ?? '',
    quantidade: lerNum(d['quantidade']),
    unidade: UnidadeEstoque.fromName(d['unidade'] as String?),
    local: lerTexto(d['local']),
    fisicoAntes: lerNum(d['fisicoAntes']),
    fisicoDepois: lerNum(d['fisicoDepois']),
    movimentacaoId: lerTexto(d['movimentacaoId']),
  );

  Map<String, dynamic> toMap() => semNulos({
    'materialId': materialId,
    'materialNome': materialNome,
    'quantidade': quantidade,
    'unidade': unidade.name,
    'local': local,
    'fisicoAntes': fisicoAntes,
    'fisicoDepois': fisicoDepois,
    'movimentacaoId': movimentacaoId,
  });
}

/// Documento imutável de `comprovantes/{id}`: a ficha que prova a retirada
/// (para quem foi entregue) ou a entrada (de quem veio). Numerado em
/// sequência por `contadores/comprovantes`.
class Comprovante {
  final String id;
  final int numero;
  final TipoComprovante tipo;
  final List<ItemComprovante> itens;

  /// Retirada: quem recebeu o material (obrigatório) e a função/setor.
  final String? recebedorNome;
  final String? recebedorFuncao;

  /// Entrada: fornecedor ou pessoa que trouxe o material.
  final String? origemNome;
  final String? notaNumero;

  final String? clienteNome;
  final String? projetoNome;
  final String? listaCorteId;
  final String motivo;
  final String? observacao;

  /// Quem registrou (entregou, na retirada; conferiu, na entrada).
  final String responsavelId;
  final String responsavelNome;

  /// Assinatura de quem recebeu, PNG em base64. Nula = não coletada.
  final String? assinaturaPng;

  /// "Gerenciador" (celular) ou "Cérebro" (painel).
  final String? registradoNo;
  final DateTime? criadoEm;

  const Comprovante({
    required this.id,
    required this.numero,
    required this.tipo,
    required this.itens,
    this.recebedorNome,
    this.recebedorFuncao,
    this.origemNome,
    this.notaNumero,
    this.clienteNome,
    this.projetoNome,
    this.listaCorteId,
    required this.motivo,
    this.observacao,
    required this.responsavelId,
    required this.responsavelNome,
    this.assinaturaPng,
    this.registradoNo,
    this.criadoEm,
  });

  bool get assinado => assinaturaPng != null;

  /// "00042".
  String get numeroFormatado => numero.toString().padLeft(5, '0');

  /// Retirada: quem recebeu. Entrada: de quem veio.
  String? get contraparte => tipo == TipoComprovante.retirada ? recebedorNome : origemNome;

  /// "Cozinha · Rodrigues".
  String? get destino {
    final partes = [projetoNome, clienteNome].whereType<String>().toList();
    return partes.isEmpty ? null : partes.join(' · ');
  }

  factory Comprovante.fromMap(String id, Map<String, dynamic> d) => Comprovante(
    id: id,
    numero: lerNum(d['numero']).toInt(),
    tipo: TipoComprovante.fromName(d['tipo'] as String?),
    itens: lerListaMapas(d['itens']).map(ItemComprovante.fromMap).toList(),
    recebedorNome: lerTexto(d['recebedorNome']),
    recebedorFuncao: lerTexto(d['recebedorFuncao']),
    origemNome: lerTexto(d['origemNome']),
    notaNumero: lerTexto(d['notaNumero']),
    clienteNome: lerTexto(d['clienteNome']),
    projetoNome: lerTexto(d['projetoNome']),
    listaCorteId: lerTexto(d['listaCorteId']),
    motivo: lerTexto(d['motivo']) ?? '',
    observacao: lerTexto(d['observacao']),
    responsavelId: lerTexto(d['responsavelId']) ?? 'sistema',
    responsavelNome: lerTexto(d['responsavelNome']) ?? 'Sistema',
    assinaturaPng: lerTexto(d['assinaturaPng']),
    registradoNo: lerTexto(d['registradoNo']),
    criadoEm: lerData(d['criadoEm']),
  );

  factory Comprovante.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Comprovante.fromMap(doc.id, doc.data() ?? const {});

  /// Sem `criadoEm`: quem grava usa `FieldValue.serverTimestamp()`.
  Map<String, dynamic> toMap() => semNulos({
    'numero': numero,
    'tipo': tipo.name,
    'itens': [for (final i in itens) i.toMap()],
    'recebedorNome': recebedorNome,
    'recebedorFuncao': recebedorFuncao,
    'origemNome': origemNome,
    'notaNumero': notaNumero,
    'clienteNome': clienteNome,
    'projetoNome': projetoNome,
    'listaCorteId': listaCorteId,
    'motivo': motivo,
    'observacao': observacao,
    'responsavelId': responsavelId,
    'responsavelNome': responsavelNome,
    'assinaturaPng': assinaturaPng,
    'registradoNo': registradoNo,
  });

  Comprovante copyWith({DateTime? criadoEm}) => Comprovante(
    id: id,
    numero: numero,
    tipo: tipo,
    itens: itens,
    recebedorNome: recebedorNome,
    recebedorFuncao: recebedorFuncao,
    origemNome: origemNome,
    notaNumero: notaNumero,
    clienteNome: clienteNome,
    projetoNome: projetoNome,
    listaCorteId: listaCorteId,
    motivo: motivo,
    observacao: observacao,
    responsavelId: responsavelId,
    responsavelNome: responsavelNome,
    assinaturaPng: assinaturaPng,
    registradoNo: registradoNo,
    criadoEm: criadoEm ?? this.criadoEm,
  );
}
