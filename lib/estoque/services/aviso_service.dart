import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Grava eventos em `avisos`. Nunca lança: aviso perdido não pode travar
/// uma importação ou uma baixa.
class AvisoService {
  AvisoService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Chamado depois de gravar, pra notificação do sistema operacional
  /// (registrado pelo Cérebro; o Gerenciador não registra).
  static void Function(Aviso aviso)? notificarSO;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('avisos');

  Future<void> registrar(
    TipoAviso tipo,
    String texto, {
    String? listaCorteId,
    String? pedidoId,
    String? notaFiscalId,
  }) async {
    final aviso = Aviso(
      id: '',
      tipo: tipo,
      texto: texto,
      listaCorteId: listaCorteId,
      pedidoId: pedidoId,
      notaFiscalId: notaFiscalId,
    );
    try {
      await _col.add({
        ...aviso.toMap(),
        'criadoEm': FieldValue.serverTimestamp(),
      });
      notificarSO?.call(aviso);
    } catch (e) {
      debugPrint('Aviso não gravado ($texto): $e');
    }
  }

  Stream<List<Aviso>> recentes({int limite = 30}) => _col
      .orderBy('criadoEm', descending: true)
      .limit(limite)
      .snapshots()
      .map((s) => s.docs.map(Aviso.fromFirestore).toList());

  Future<void> marcarLido(String id) =>
      _col.doc(id).update({'lido': true});

  Future<void> marcarTodosLidos() async {
    final s = await _col.where('lido', isEqualTo: false).get();
    final batch = _db.batch();
    for (final d in s.docs) {
      batch.update(d.reference, {'lido': true});
    }
    await batch.commit();
  }
}
