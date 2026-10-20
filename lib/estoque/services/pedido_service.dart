import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../util/quantidade.dart';
import 'aviso_service.dart';
import 'estoque_service.dart';
import 'reserva_service.dart';

/// Pedidos de compra por fornecedor.
///
/// O rascunho de cada fornecedor tem id fixo (`rascunho_<fornecedorId>` ou
/// `rascunho_sem`), então "no máximo um rascunho por fornecedor" é garantido
/// pela própria transação. Ao enviar, o rascunho vira um pedido com id novo.
class PedidoService {
  PedidoService({FirebaseFirestore? db, EstoqueService? estoque})
    : _db = db ?? FirebaseFirestore.instance,
      _estoque = estoque;

  final FirebaseFirestore _db;
  final EstoqueService? _estoque;

  EstoqueService get _est => _estoque ?? EstoqueService.sistema(db: _db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('pedidos_compra');

  static String idRascunho(String? fornecedorId) =>
      'rascunho_${fornecedorId ?? 'sem'}';

  // --------------------------------------------------------- rascunho

  /// Deixa no rascunho do fornecedor exatamente o que falta à lista desse
  /// material ([faltaTotal]), descontando o que já foi enviado e ainda não
  /// chegou. Idempotente: reprocessar a lista não duplica o pedido.
  Future<void> definirFaltaDaLista({
    required MaterialEstoque material,
    required String listaCorteId,
    required double faltaTotal,
    required String destino,
  }) async {
    final enviados = await _col
        .where('status', whereIn: [StatusPedido.enviado.name, StatusPedido.recebidoParcial.name])
        .get();
    var aCaminho = 0.0;
    for (final d in enviados.docs) {
      for (final i in PedidoCompra.fromFirestore(d).itens) {
        if (i.materialId != material.id) continue;
        final daLista = i.porLista[listaCorteId] ?? 0;
        final pendente = (i.quantidade - i.qtdRecebida).clamp(0, double.infinity);
        aCaminho += daLista.clamp(0, pendente);
      }
    }
    final alvo = (faltaTotal - aCaminho).clamp(0, double.infinity).toDouble();
    await _mexerNoRascunho(material, (item) {
      final atual = item?.porLista[listaCorteId] ?? 0;
      if ((atual - alvo).abs() < 1e-9) return item;
      final porLista = Map.of(item?.porLista ?? const <String, double>{});
      if (alvo <= 0) {
        porLista.remove(listaCorteId);
      } else {
        porLista[listaCorteId] = alvo;
      }
      if (item == null && alvo <= 0) return null;
      return _montar(
        material,
        item,
        porLista: porLista,
        destinoNovo: alvo > 0 ? destino : null,
      );
    });
  }

  /// Tira de rascunho a parte que veio de [listaCorteId] (lista cancelada,
  /// cortada, ou falta coberta por outro caminho).
  Future<void> reduzirLista({
    required String materialId,
    required String listaCorteId,
    double? quantidade,
  }) async {
    final snaps = await _col.where('status', isEqualTo: StatusPedido.rascunho.name).get();
    for (final doc in snaps.docs) {
      final p = PedidoCompra.fromFirestore(doc);
      if (!p.itens.any((i) => i.materialId == materialId && i.porLista.containsKey(listaCorteId))) {
        continue;
      }
      await _db.runTransaction((tx) async {
        final atual = PedidoCompra.fromFirestore(await tx.get(doc.reference));
        final itens = <ItemPedido>[];
        for (final i in atual.itens) {
          if (i.materialId != materialId || !i.porLista.containsKey(listaCorteId)) {
            itens.add(i);
            continue;
          }
          final porLista = Map.of(i.porLista);
          final tinha = porLista[listaCorteId]!;
          final tira = quantidade == null ? tinha : quantidade.clamp(0, tinha).toDouble();
          if (tinha - tira <= 1e-9) {
            porLista.remove(listaCorteId);
          } else {
            porLista[listaCorteId] = tinha - tira;
          }
          final novo = i.copyWith(
            porLista: porLista,
            listaCorteIds: porLista.keys.toList(),
            quantidade: (i.quantidade - tira).clamp(0, double.infinity).toDouble(),
            origem: porLista.isEmpty ? OrigemItemPedido.minimo : OrigemItemPedido.lista,
          );
          if (novo.quantidade > 1e-9) itens.add(novo);
        }
        _gravarRascunho(tx, doc.reference, atual, itens);
      });
    }
  }

  Future<void> removerListaDosRascunhos(ListaCorte lista) async {
    for (final i in lista.itens.where((i) => i.materialId != null)) {
      await reduzirLista(materialId: i.materialId!, listaCorteId: lista.id);
    }
  }

  /// Estoque mínimo: se o disponível ficou abaixo do mínimo, garante no
  /// rascunho a quantidade que o leva de volta, sem duplicar o que já está
  /// pedido (rascunho ou enviado ainda não recebido).
  Future<void> garantirMinimo(MaterialEstoque m) async {
    if (!m.ativo || m.estoqueMinimo <= 0) return;
    final faltaMinimo = m.estoqueMinimo - m.disponivel;
    if (faltaMinimo <= 0) return;

    final enviados = await _col
        .where('status', whereIn: [StatusPedido.enviado.name, StatusPedido.recebidoParcial.name])
        .get();
    var aCaminho = 0.0;
    for (final d in enviados.docs) {
      for (final i in PedidoCompra.fromFirestore(d).itens.where((i) => i.materialId == m.id)) {
        final pendente = i.quantidade - i.qtdRecebida;
        aCaminho += pendente.clamp(0, i.qtdMinimo);
      }
    }
    final alvo = arredondarParaUnidade(faltaMinimo - aCaminho, m.unidade);
    if (alvo <= 0) return;

    await _mexerNoRascunho(m, (item) {
      if ((item?.qtdMinimo ?? 0) >= alvo) return item; // já está no pedido
      return _montar(m, item, qtdMinimo: alvo);
    });
  }

  /// Liga o estoque mínimo a toda movimentação (vale venha de onde vier).
  static void registrarOuvinteMinimo() {
    if (_ouvinteRegistrado) return;
    _ouvinteRegistrado = true;
    EstoqueService.ouvintes.add((m, _) => PedidoService().garantirMinimo(m));
  }

  static bool _ouvinteRegistrado = false;

  /// Edição inline da quantidade (comprar a mais). 0 tira o item.
  Future<void> alterarQuantidade(String pedidoId, String materialId, double nova) async {
    final ref = _col.doc(pedidoId);
    await _db.runTransaction((tx) async {
      final p = PedidoCompra.fromFirestore(await tx.get(ref));
      final itens = [
        for (final i in p.itens)
          if (i.materialId != materialId) i else if (nova > 0) i.copyWith(quantidade: nova),
      ];
      _gravarRascunho(tx, ref, p, itens);
    });
  }

  /// "Escolher fornecedor" no card "Sem fornecedor": grava o fornecedor nos
  /// materiais e muda os itens pro rascunho dele.
  Future<void> definirFornecedor(PedidoCompra semFornecedor, Fornecedor f) async {
    for (final i in semFornecedor.itens) {
      await _db.collection('materiais').doc(i.materialId).update({
        'fornecedorId': f.id,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });
    }
    final destino = _col.doc(idRascunho(f.id));
    await _db.runTransaction((tx) async {
      final origem = PedidoCompra.fromFirestore(await tx.get(_col.doc(semFornecedor.id)));
      final snap = await tx.get(destino);
      final atual = snap.exists
          ? PedidoCompra.fromFirestore(snap)
          : PedidoCompra(id: destino.id, fornecedorId: f.id, fornecedorNome: f.nome, status: StatusPedido.rascunho);
      final itens = List.of(atual.itens);
      for (final i in origem.itens) {
        final idx = itens.indexWhere((x) => x.materialId == i.materialId);
        if (idx < 0) {
          itens.add(i);
        } else {
          final x = itens[idx];
          final porLista = Map.of(x.porLista);
          i.porLista.forEach((k, v) => porLista[k] = (porLista[k] ?? 0) + v);
          itens[idx] = x.copyWith(
            quantidade: x.quantidade + i.quantidade,
            qtdMinimo: x.qtdMinimo + i.qtdMinimo,
            porLista: porLista,
            listaCorteIds: porLista.keys.toList(),
            destinos: {...x.destinos, ...i.destinos}.toList(),
          );
        }
      }
      _gravarRascunho(tx, destino, atual.copyWith(fornecedorNome: f.nome), itens);
      tx.delete(_col.doc(semFornecedor.id));
    });
  }

  // ------------------------------------------------------------ envio

  /// Texto do pedido no formato combinado com os fornecedores.
  static String mensagem(PedidoCompra p) {
    final b = StringBuffer('Olá, ${p.fornecedorNome}! Pedido da Dellalio:\n\n');
    for (final i in p.itens) {
      b.write('• ${fmtNumero(i.quantidade)} ${i.unidade.sigla} — ${i.nome}');
      if (i.refFornecedor != null) b.write(' (ref. ${i.refFornecedor})');
      b.write('\n');
    }
    b.write('\nObrigado!');
    return b.toString();
  }

  /// Abre o WhatsApp com a mensagem pronta e marca o pedido como enviado.
  /// Sem WhatsApp cadastrado: copia a mensagem e devolve `false` (a tela
  /// avisa). O pedido vira `enviado` nos dois casos.
  Future<bool> enviarWhatsApp(PedidoCompra p, Fornecedor? f) async {
    final texto = mensagem(p);
    final numero = f?.whatsapp?.replaceAll(RegExp(r'\D'), '');
    var abriu = false;
    if (numero != null && numero.length >= 10) {
      final uri = Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(texto)}');
      abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (!abriu) await Clipboard.setData(ClipboardData(text: texto));
    await marcarEnviado(p);
    return abriu;
  }

  /// Rascunho → pedido enviado (id novo), liberando o fornecedor pra um
  /// rascunho novo.
  Future<String> marcarEnviado(PedidoCompra p) async {
    final novo = _col.doc();
    final batch = _db.batch();
    batch.set(novo, {
      ...p.copyWith(status: StatusPedido.enviado).toMap(),
      'criadoEm': p.criadoEm == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(p.criadoEm!),
      'enviadoEm': FieldValue.serverTimestamp(),
    });
    batch.delete(_col.doc(p.id));
    await batch.commit();
    return novo.id;
  }

  // -------------------------------------------------------- recebimento

  /// Entrada do material (nota fiscal ou botão "Recebido"), realocação pras
  /// listas que esperavam por ele e atualização do pedido. Devolve o id da
  /// movimentação de entrada.
  Future<String?> registrarRecebimento({
    required String materialId,
    required double quantidade,
    double? custoUnitario,
    String? fornecedorId,
    String? fornecedorNome,
    String? notaFiscalId,
    String? pedidoId,
  }) async {
    final movId = await _est.entrada(
      materialId: materialId,
      quantidade: quantidade,
      custoUnitario: custoUnitario,
      motivo: 'Compra',
      fornecedorNome: fornecedorNome,
      notaFiscalId: notaFiscalId,
      pedidoId: pedidoId,
      origem: notaFiscalId != null ? OrigemMovimentacao.notaFiscal : OrigemMovimentacao.manual,
    );
    try {
      await _abaterNoPedido(materialId, quantidade, pedidoId: pedidoId, fornecedorId: fornecedorId);
    } catch (e) {
      debugPrint('Pedido não atualizado: $e');
    }
    await ReservaService(db: _db).realocar({materialId});
    return movId;
  }

  /// Botão "Recebido": dá entrada no que faltava de cada item.
  Future<void> marcarRecebido(PedidoCompra p) async {
    for (final i in p.itens) {
      final falta = i.quantidade - i.qtdRecebida;
      if (falta <= 0) continue;
      await registrarRecebimento(
        materialId: i.materialId,
        quantidade: falta,
        fornecedorId: p.fornecedorId,
        fornecedorNome: p.fornecedorNome,
        pedidoId: p.id,
      );
    }
  }

  /// Soma o recebido no pedido indicado ou, sem ele, nos pedidos enviados
  /// do fornecedor que têm o material (mais antigo primeiro).
  Future<void> _abaterNoPedido(
    String materialId,
    double quantidade, {
    String? pedidoId,
    String? fornecedorId,
  }) async {
    List<DocumentReference<Map<String, dynamic>>> refs;
    if (pedidoId != null) {
      refs = [_col.doc(pedidoId)];
    } else {
      var q = _col.where('status', whereIn: [StatusPedido.enviado.name, StatusPedido.recebidoParcial.name]);
      if (fornecedorId != null) q = q.where('fornecedorId', isEqualTo: fornecedorId);
      final s = await q.get();
      final ps = s.docs.map(PedidoCompra.fromFirestore).where((p) => p.itens.any((i) => i.materialId == materialId)).toList()
        ..sort((a, b) => (a.enviadoEm ?? DateTime(2100)).compareTo(b.enviadoEm ?? DateTime(2100)));
      refs = ps.map((p) => _col.doc(p.id)).toList();
    }
    var resta = quantidade;
    for (final ref in refs) {
      if (resta <= 0) break;
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final p = PedidoCompra.fromFirestore(snap);
        if (p.status == StatusPedido.rascunho || p.status == StatusPedido.recebido) return;
        final itens = [
          for (final i in p.itens)
            if (i.materialId == materialId && resta > 0)
              () {
                final abate = (i.quantidade - i.qtdRecebida).clamp(0, resta).toDouble();
                resta -= abate;
                return i.copyWith(qtdRecebida: i.qtdRecebida + abate);
              }()
            else
              i,
        ];
        final completo = itens.every((i) => i.qtdRecebida >= i.quantidade - 1e-9);
        tx.update(ref, {
          'itens': itens.map((i) => i.toMap()).toList(),
          'status': (completo ? StatusPedido.recebido : StatusPedido.recebidoParcial).name,
          if (completo) 'recebidoEm': FieldValue.serverTimestamp(),
        });
      });
    }
  }

  // ------------------------------------------------------------ apoio

  Future<void> _mexerNoRascunho(
    MaterialEstoque m,
    ItemPedido? Function(ItemPedido? atual) alterar,
  ) async {
    final fornecedorId = m.fornecedorId;
    String fornecedorNome = PedidoCompra.semFornecedorNome;
    if (fornecedorId != null) {
      final f = await _db.collection('fornecedores').doc(fornecedorId).get();
      fornecedorNome = (f.data()?['nome'] ?? 'Fornecedor').toString();
    }
    final ref = _col.doc(idRascunho(fornecedorId));
    final novoPedido = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final atual = snap.exists
          ? PedidoCompra.fromFirestore(snap)
          : PedidoCompra(
              id: ref.id,
              fornecedorId: fornecedorId,
              fornecedorNome: fornecedorNome,
              status: StatusPedido.rascunho,
            );
      final idx = atual.itens.indexWhere((i) => i.materialId == m.id);
      final novo = alterar(idx < 0 ? null : atual.itens[idx]);
      final itens = List.of(atual.itens);
      if (novo == null || novo.quantidade <= 0) {
        if (idx >= 0) itens.removeAt(idx);
      } else if (idx < 0) {
        itens.add(novo);
      } else {
        itens[idx] = novo;
      }
      _gravarRascunho(tx, ref, atual, itens);
      return !snap.exists;
    });
    if (novoPedido) {
      await AvisoService(db: _db).registrar(
        TipoAviso.pedidoPronto,
        'Novo pedido de compra para $fornecedorNome.',
        pedidoId: ref.id,
      );
    }
  }

  ItemPedido _montar(
    MaterialEstoque m,
    ItemPedido? item, {
    Map<String, double>? porLista,
    double? qtdMinimo,
    String? destinoNovo,
  }) {
    final pl = porLista ?? item?.porLista ?? const <String, double>{};
    final minimo = qtdMinimo ?? item?.qtdMinimo ?? 0;
    final daLista = pl.values.fold<double>(0, (s, v) => s + v);
    // Se a quantidade tinha sido aumentada à mão, mantém o extra.
    final extra = item == null
        ? 0.0
        : (item.quantidade - item.porLista.values.fold<double>(0, (s, v) => s + v) - item.qtdMinimo)
              .clamp(0, double.infinity)
              .toDouble();
    final destinos = {
      ...?item?.destinos,
      ?destinoNovo,
      if (minimo > 0) 'repor mínimo',
    }.toList();
    return ItemPedido(
      materialId: m.id,
      nome: m.nome,
      refFornecedor: m.refFornecedor,
      quantidade: arredondarParaUnidade(daLista + minimo + extra, m.unidade),
      unidade: m.unidade,
      origem: pl.isEmpty ? OrigemItemPedido.minimo : OrigemItemPedido.lista,
      listaCorteIds: pl.keys.toList(),
      porLista: pl,
      qtdMinimo: minimo,
      qtdRecebida: item?.qtdRecebida ?? 0,
      destinos: destinos,
    );
  }

  void _gravarRascunho(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
    PedidoCompra atual,
    List<ItemPedido> itens,
  ) {
    if (itens.isEmpty) {
      tx.delete(ref);
      return;
    }
    tx.set(ref, {
      ...atual.copyWith(itens: itens).toMap(),
      'criadoEm': atual.criadoEm == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(atual.criadoEm!),
    });
  }
}
