import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'leitura.dart';

/// Documento de `avisos/{id}` — eventos que o sino e a visão geral mostram.
class Aviso {
  final String id;
  final TipoAviso tipo;
  final String texto;
  final String? listaCorteId;
  final String? pedidoId;
  final String? notaFiscalId;
  final bool lido;
  final DateTime? criadoEm;

  const Aviso({
    required this.id,
    required this.tipo,
    required this.texto,
    this.listaCorteId,
    this.pedidoId,
    this.notaFiscalId,
    this.lido = false,
    this.criadoEm,
  });

  factory Aviso.fromMap(String id, Map<String, dynamic> d) => Aviso(
    id: id,
    tipo: TipoAviso.fromName(d['tipo'] as String?),
    texto: lerTexto(d['texto']) ?? '',
    listaCorteId: lerTexto(d['listaCorteId']),
    pedidoId: lerTexto(d['pedidoId']),
    notaFiscalId: lerTexto(d['notaFiscalId']),
    lido: d['lido'] == true,
    criadoEm: lerData(d['criadoEm']),
  );

  factory Aviso.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Aviso.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => semNulos({
    'tipo': tipo.name,
    'texto': texto,
    'listaCorteId': listaCorteId,
    'pedidoId': pedidoId,
    'notaFiscalId': notaFiscalId,
    'lido': lido,
  });

  Aviso copyWith({bool? lido}) => Aviso(
    id: id,
    tipo: tipo,
    texto: texto,
    listaCorteId: listaCorteId,
    pedidoId: pedidoId,
    notaFiscalId: notaFiscalId,
    lido: lido ?? this.lido,
    criadoEm: criadoEm,
  );
}
