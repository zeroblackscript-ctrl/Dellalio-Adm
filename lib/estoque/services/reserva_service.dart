import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'aviso_service.dart';
import 'consultas.dart';
import 'estoque_service.dart';
import 'pedido_service.dart';

/// Reservas das listas de corte e realocação quando chega material.
///
/// Ordem justa: listas são atendidas por ordem de chegada. Antes de
/// reservar pra uma lista, as listas anteriores que esperam o mesmo
/// material são atendidas primeiro — uma lista nova nunca passa na frente.
class ReservaService {
  ReservaService({FirebaseFirestore? db, EstoqueService? estoque})
    : _db = db ?? FirebaseFirestore.instance,
      _estoque = estoque;

  final FirebaseFirestore _db;
  final EstoqueService? _estoque;

  EstoqueService get _est => _estoque ?? EstoqueService.sistema(db: _db);
  PedidoService get _pedidos => PedidoService(db: _db, estoque: _est);
  DocumentReference<Map<String, dynamic>> _ref(String id) =>
      _db.collection('listas_corte').doc(id);

  /// Reserva os itens casados da lista (todos, ou só [indices]) e acerta o
  /// pedido de compra do que faltar.
  Future<ListaCorte> reservarLista(ListaCorte lista, {Iterable<int>? indices}) async {
    final alvos = (indices ?? List.generate(lista.itens.length, (i) => i)).where((i) {
      final it = lista.itens[i];
      return it.materialId != null &&
          it.situacao != SituacaoItem.confirmar &&
          it.quantidade - it.qtdReservada > 1e-9;
    }).toList();
    final materiais = {for (final i in alvos) lista.itens[i].materialId!};
    if (materiais.isEmpty) return _gravar(lista.id, const {});

    // Primeiro quem chegou antes.
    await realocar(materiais, excetoListaId: lista.id, chegadaAte: lista.criadoEm);

    final novos = <int, ItemListaCorte>{};
    for (final i in alvos) {
      final it = lista.itens[i];
      double r = 0;
      try {
        r = await _est.reservar(
          materialId: it.materialId!,
          quantidadeDesejada: it.quantidade - it.qtdReservada,
          listaCorteId: lista.id,
          clienteNome: lista.clienteNome,
          projetoNome: lista.projetoNome,
        );
      } catch (e) {
        // Falha num item não aborta os outros: ele fica como falta.
        debugPrint('Reserva falhou (${it.descricaoOriginal}): $e');
      }
      novos[i] = comReserva(it, it.qtdReservada + r);
    }
    final atualizada = await _gravar(lista.id, novos);
    await _acertarPedido(atualizada, materiais);
    return atualizada;
  }

  /// Distribui o disponível dos [materialIds] entre as listas que esperam
  /// por eles, na ordem de chegada.
  Future<void> realocar(
    Set<String> materialIds, {
    String? excetoListaId,
    DateTime? chegadaAte,
  }) async {
    if (materialIds.isEmpty) return;
    final snap = await _db
        .collection('listas_corte')
        .where('status', isEqualTo: StatusLista.aguardandoCompra.name)
        .get();
    final listas = snap.docs.map(ListaCorte.fromFirestore).toList()
      ..sort(Consultas.porChegada);

    for (final lista in listas) {
      if (lista.id == excetoListaId) continue;
      if (chegadaAte != null && lista.criadoEm != null && !lista.criadoEm!.isBefore(chegadaAte)) {
        continue;
      }
      final novos = <int, ItemListaCorte>{};
      final tocados = <String>{};
      for (var i = 0; i < lista.itens.length; i++) {
        final it = lista.itens[i];
        if (it.materialId == null ||
            !materialIds.contains(it.materialId) ||
            it.situacao == SituacaoItem.confirmar ||
            it.qtdFaltante <= 1e-9) {
          continue;
        }
        try {
          final r = await _est.reservar(
            materialId: it.materialId!,
            quantidadeDesejada: it.qtdFaltante,
            listaCorteId: lista.id,
            clienteNome: lista.clienteNome,
            projetoNome: lista.projetoNome,
            motivo: 'Material chegou',
          );
          if (r > 0) {
            novos[i] = comReserva(it, it.qtdReservada + r);
            tocados.add(it.materialId!);
          }
        } catch (e) {
          debugPrint('Realocação falhou (${it.descricaoOriginal}): $e');
        }
      }
      if (novos.isEmpty) continue;
      final atualizada = await _gravar(lista.id, novos);
      await _acertarPedido(atualizada, tocados);
    }
  }

  /// Libera tudo que a lista reservou (cancelamento).
  Future<void> liberarLista(ListaCorte lista, {String motivo = 'Lista cancelada'}) async {
    final novos = <int, ItemListaCorte>{};
    for (var i = 0; i < lista.itens.length; i++) {
      final it = lista.itens[i];
      if (it.materialId == null || it.qtdReservada <= 0) continue;
      try {
        await _est.liberarReserva(
          materialId: it.materialId!,
          quantidade: it.qtdReservada,
          listaCorteId: lista.id,
          motivo: motivo,
          clienteNome: lista.clienteNome,
          projetoNome: lista.projetoNome,
        );
        novos[i] = it.copyWith(qtdReservada: 0, qtdFaltante: it.quantidade);
      } catch (e) {
        debugPrint('Liberação falhou (${it.descricaoOriginal}): $e');
      }
    }
    if (novos.isNotEmpty) await _gravar(lista.id, novos, manterStatus: true);
  }

  /// Item com a reserva nova: faltante e situação recalculados.
  static ItemListaCorte comReserva(ItemListaCorte it, double reservado) {
    final falta = (it.quantidade - reservado).clamp(0, double.infinity).toDouble();
    final situacao = falta <= 1e-9
        ? SituacaoItem.ok
        : reservado > 1e-9
        ? SituacaoItem.parcial
        : SituacaoItem.falta;
    return it.copyWith(qtdReservada: reservado, qtdFaltante: falta, situacao: situacao);
  }

  /// Status da lista pelos itens: `confirmar` não bloqueia o resto.
  static StatusLista statusDe(List<ItemListaCorte> itens, StatusLista atual) {
    if (atual == StatusLista.cortada || atual == StatusLista.cancelada) return atual;
    final casados = itens.where((i) => i.situacao != SituacaoItem.confirmar).toList();
    if (casados.isEmpty) return StatusLista.lida;
    final faltando = casados.any((i) => i.situacao == SituacaoItem.parcial || i.situacao == SituacaoItem.falta);
    if (faltando) return StatusLista.aguardandoCompra;
    if (atual == StatusLista.aguardandoCompra) return StatusLista.pronta;
    if (atual == StatusLista.lida) return StatusLista.reservada;
    return atual;
  }

  /// Troca só os itens alterados (outro processo pode ter mexido em outros)
  /// e recalcula status/resumo. Avisa quando a lista fica pronta.
  Future<ListaCorte> _gravar(
    String listaId,
    Map<int, ItemListaCorte> novos, {
    bool manterStatus = false,
  }) async {
    final (antes, depois) = await _db.runTransaction<(StatusLista, ListaCorte)>((tx) async {
      final atual = ListaCorte.fromFirestore(await tx.get(_ref(listaId)));
      final itens = [
        for (var i = 0; i < atual.itens.length; i++) novos[i] ?? atual.itens[i],
      ];
      final status = manterStatus ? atual.status : statusDe(itens, atual.status);
      final nova = atual.copyWith(itens: itens, status: status);
      tx.update(_ref(listaId), {
        'itens': itens.map((i) => i.toMap()).toList(),
        'resumo': nova.resumo.toMap(),
        'status': status.name,
      });
      return (atual.status, nova);
    });
    if (antes == StatusLista.aguardandoCompra && depois.status == StatusLista.pronta) {
      await AvisoService(db: _db).registrar(
        TipoAviso.listaPronta,
        '${depois.titulo} está pronta para cortar.',
        listaCorteId: listaId,
      );
    }
    return depois;
  }

  /// Rascunho do pedido = faltante atual da lista, por material.
  Future<void> _acertarPedido(ListaCorte lista, Set<String> materialIds) async {
    for (final id in materialIds) {
      final falta = lista.itens
          .where((i) => i.materialId == id && i.situacao != SituacaoItem.confirmar)
          .fold<double>(0, (s, i) => s + i.qtdFaltante);
      try {
        final snap = await _db.collection('materiais').doc(id).get();
        if (!snap.exists) continue;
        await _pedidos.definirFaltaDaLista(
          material: MaterialEstoque.fromFirestore(snap),
          listaCorteId: lista.id,
          faltaTotal: falta,
          destino: lista.titulo,
        );
      } catch (e) {
        debugPrint('Pedido não acertado ($id): $e');
      }
    }
  }
}
