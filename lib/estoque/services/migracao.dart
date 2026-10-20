import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../util/normalizar.dart';
import '../util/quantidade.dart';
import 'responsavel.dart';

/// Converte o estoque antigo (`stock`: name, category, quantity,
/// minQuantity, imageUrl) pro modelo novo (`materiais`), uma vez só.
///
/// - Cada item vira `materiais/{mesmo id}`, com uma movimentação `ajuste`
///   "Saldo inicial (migração)" quando tinha saldo, na mesma transação.
/// - Idempotente: material que já existe é pulado, então duas máquinas
///   rodando ao mesmo tempo não duplicam nada.
/// - Protegida pela flag `config/migracoes.estoqueAntigo`.
/// - Nada é apagado: `stock` e `stock_history` ficam como estão.
Future<int> migrarEstoqueAntigo({FirebaseFirestore? db}) async {
  final fs = db ?? FirebaseFirestore.instance;
  final flagRef = fs.collection('config').doc('migracoes');
  final flag = await flagRef.get();
  if (flag.data()?['estoqueAntigo'] == true) return 0;

  final antigos = await fs.collection('stock').get();
  var migrados = 0;
  for (final doc in antigos.docs) {
    try {
      if (await _migrarItem(fs, doc)) migrados++;
    } catch (e) {
      // Um item ruim não impede os outros; a flag só sobe se tudo passou.
      debugPrint('Migração: item ${doc.id} falhou: $e');
      return migrados;
    }
  }
  await flagRef.set({
    'estoqueAntigo': true,
    'estoqueAntigoEm': FieldValue.serverTimestamp(),
    'estoqueAntigoItens': migrados,
  }, SetOptions(merge: true));
  return migrados;
}

Future<bool> _migrarItem(
  FirebaseFirestore fs,
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  final d = doc.data();
  final nome = (d['name'] ?? '').toString().trim();
  final categoriaAntiga = (d['category'] ?? '').toString();
  final categoria = inferirCategoria('$categoriaAntiga $nome');
  final unidade = unidadePadrao(categoria);
  final qtd = (d['quantity'] is num) ? (d['quantity'] as num).toDouble() : 0.0;
  final minimo = (d['minQuantity'] is num)
      ? (d['minQuantity'] as num).toDouble()
      : 0.0;
  final fisico = qtd < 0 ? 0.0 : arredondarParaUnidade(qtd, unidade);

  final ref = fs.collection('materiais').doc(doc.id);
  return fs.runTransaction<bool>((tx) async {
    if ((await tx.get(ref)).exists) return false;
    final material = MaterialEstoque(
      id: doc.id,
      nome: nome.isEmpty ? 'Sem nome' : nome,
      categoria: categoria,
      unidade: unidade,
      apelidos: [if (nome.isNotEmpty) normalizar(nome)],
      estoqueFisico: fisico,
      estoqueMinimo: minimo,
    );
    tx.set(ref, {
      ...material.toMap(),
      if ((d['imageUrl'] ?? '').toString().isNotEmpty) 'imagemUrl': d['imageUrl'],
      'migradoDe': 'stock',
      'criadoEm': FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
    if (fisico > 0) {
      final movRef = fs.collection('movimentacoes').doc();
      final mov = Movimentacao(
        id: movRef.id,
        materialId: doc.id,
        materialNome: material.nome,
        tipo: TipoMovimentacao.ajuste,
        quantidade: fisico,
        unidade: unidade,
        motivo: 'Saldo inicial (migração)',
        origem: OrigemMovimentacao.sistema,
        responsavelId: Responsavel.sistema.id,
        responsavelNome: Responsavel.sistema.nome,
        fisicoAntes: 0,
        fisicoDepois: fisico,
        reservadoAntes: 0,
        reservadoDepois: 0,
      );
      tx.set(movRef, {...mov.toMap(), 'criadoEm': FieldValue.serverTimestamp()});
    }
    return true;
  });
}
