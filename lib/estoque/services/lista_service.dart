import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'estoque_service.dart';
import 'pedido_service.dart';
import 'reserva_service.dart';

/// Fim da vida de uma lista: cortada (baixa) ou cancelada (libera tudo).
/// Usado pelo Cérebro e pelo Gerenciador — responsável = quem está logado.
class ListaService {
  ListaService({FirebaseFirestore? db, EstoqueService? estoque})
    : _db = db ?? FirebaseFirestore.instance,
      _estoque = estoque;

  final FirebaseFirestore _db;
  final EstoqueService? _estoque;

  EstoqueService get _est => _estoque ?? EstoqueService(db: _db);
  DocumentReference<Map<String, dynamic>> _ref(String id) =>
      _db.collection('listas_corte').doc(id);

  /// Itens que ainda tinham falta (pra pergunta "Foram comprados por fora?").
  static List<ItemListaCorte> faltasPendentes(ListaCorte l) => l.itens
      .where((i) => i.materialId != null && i.situacao != SituacaoItem.confirmar && i.qtdFaltante > 1e-9)
      .toList();

  /// Baixa: `saida` consumindo a reserva de cada item, origem
  /// `projetoCortado`, motivo "Produção". Com [compradoPorFora], o que
  /// faltava entra e sai na hora (comprado direto, sem passar pelo pedido).
  Future<void> marcarCortada(String listaId, {bool compradoPorFora = false}) async {
    final lista = ListaCorte.fromFirestore(await _ref(listaId).get());
    if (lista.status == StatusLista.cortada || lista.status == StatusLista.cancelada) return;

    for (final it in lista.itens) {
      if (it.materialId == null || it.situacao == SituacaoItem.confirmar) continue;
      try {
        if (it.qtdReservada > 0) {
          await _est.saida(
            materialId: it.materialId!,
            quantidade: it.qtdReservada,
            motivo: 'Produção',
            clienteNome: lista.clienteNome,
            projetoNome: lista.projetoNome,
            listaCorteId: lista.id,
            origem: OrigemMovimentacao.projetoCortado,
            consumirReserva: true,
          );
        }
        if (compradoPorFora && it.qtdFaltante > 0) {
          await _est.entrada(
            materialId: it.materialId!,
            quantidade: it.qtdFaltante,
            motivo: 'Comprado por fora',
            origem: OrigemMovimentacao.projetoCortado,
          );
          await _est.saida(
            materialId: it.materialId!,
            quantidade: it.qtdFaltante,
            motivo: 'Produção',
            clienteNome: lista.clienteNome,
            projetoNome: lista.projetoNome,
            listaCorteId: lista.id,
            origem: OrigemMovimentacao.projetoCortado,
          );
        }
      } catch (e) {
        debugPrint('Baixa falhou (${it.descricaoOriginal}): $e');
      }
    }

    // O que ainda estava no rascunho por causa desta lista não é mais preciso.
    await PedidoService(db: _db).removerListaDosRascunhos(lista);

    final resp = await _est.responsavelAtual();
    await _ref(listaId).update({
      'status': StatusLista.cortada.name,
      'cortadaEm': FieldValue.serverTimestamp(),
      'cortadaPor': resp.nome,
    });
  }

  /// Libera todas as reservas, tira dos rascunhos o que veio só desta lista
  /// e repassa o material liberado pras listas que estavam esperando.
  Future<void> cancelarLista(String listaId) async {
    final lista = ListaCorte.fromFirestore(await _ref(listaId).get());
    if (lista.status == StatusLista.cortada || lista.status == StatusLista.cancelada) return;
    final reservas = ReservaService(db: _db, estoque: _est);
    await reservas.liberarLista(lista);
    await PedidoService(db: _db).removerListaDosRascunhos(lista);
    await _ref(listaId).update({'status': StatusLista.cancelada.name});
    await reservas.realocar({
      for (final i in lista.itens)
        if (i.materialId != null) i.materialId!,
    }, excetoListaId: listaId);
  }
}
