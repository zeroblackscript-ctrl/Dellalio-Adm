import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/leitura.dart';
import '../models/models.dart';
import '../util/normalizar.dart';
import '../util/quantidade.dart';
import 'aviso_service.dart';
import 'responsavel.dart';
import 'saldo.dart';

/// Chamado depois de toda movimentação que mexe no saldo (ex.: o
/// `PedidoService` confere o estoque mínimo). Erros aqui são só logados.
typedef OuvinteSaldo =
    Future<void> Function(MaterialEstoque depois, TipoMovimentacao tipo);

/// Um material pedido no comprovante. [custoUnitario] só vale na entrada.
class ItemPedidoComprovante {
  final String materialId;
  final double quantidade;
  final double? custoUnitario;
  const ItemPedidoComprovante(this.materialId, this.quantidade, {this.custoUnitario});
}

class EstoqueException implements Exception {
  final String mensagem;
  const EstoqueException(this.mensagem);
  @override
  String toString() => mensagem;
}

/// Único lugar que muda `materiais.estoque*` (regra 1). Cada operação roda
/// num `runTransaction` curto que lê o material, aplica a regra de
/// [CalculoSaldo] e grava saldo + movimentação juntos.
class EstoqueService {
  /// Responsável = usuário logado (resolvido na primeira operação).
  EstoqueService({FirebaseFirestore? db, Responsavel? responsavel})
    : _db = db ?? FirebaseFirestore.instance,
      _responsavelFixo = responsavel;

  /// Para automações (importação, nota fiscal, realocação): "Sistema".
  EstoqueService.sistema({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance,
      _responsavelFixo = Responsavel.sistema;

  final FirebaseFirestore _db;
  final Responsavel? _responsavelFixo;

  static final List<OuvinteSaldo> ouvintes = [];

  CollectionReference<Map<String, dynamic>> get _materiais =>
      _db.collection('materiais');
  CollectionReference<Map<String, dynamic>> get _movs =>
      _db.collection('movimentacoes');

  /// Quem assina as movimentações deste serviço.
  Future<Responsavel> responsavelAtual() async =>
      _responsavelFixo ?? await Responsavel.atual(db: _db);

  // ---------------------------------------------------------------- operações

  /// Retorna o id da movimentação criada.
  Future<String?> entrada({
    required String materialId,
    required double quantidade,
    double? custoUnitario,
    String motivo = 'Compra',
    String? fornecedorNome,
    String? notaFiscalId,
    String? pedidoId,
    OrigemMovimentacao origem = OrigemMovimentacao.manual,
  }) async {
    final r = await _movimentar(
      materialId: materialId,
      tipo: TipoMovimentacao.entrada,
      origem: origem,
      motivo: motivo,
      fornecedorNome: fornecedorNome,
      notaFiscalId: notaFiscalId,
      pedidoId: pedidoId,
      calcular: (c, u) =>
          c.entrada(arredondarParaUnidade(quantidade, u), custoUnitario: custoUnitario),
    );
    return r.movimentacaoId;
  }

  /// Com [consumirReserva] baixa físico **e** reservado (projeto cortado).
  /// Retorna a quantidade efetivamente baixada.
  Future<double> saida({
    required String materialId,
    required double quantidade,
    String motivo = 'Produção',
    String? clienteNome,
    String? projetoNome,
    String? listaCorteId,
    OrigemMovimentacao origem = OrigemMovimentacao.manual,
    bool consumirReserva = false,
  }) async {
    final r = await _movimentar(
      materialId: materialId,
      tipo: TipoMovimentacao.saida,
      origem: origem,
      motivo: motivo,
      clienteNome: clienteNome,
      projetoNome: projetoNome,
      listaCorteId: listaCorteId,
      calcular: (c, u) => c.saida(
        arredondarParaUnidade(quantidade, u),
        consumirReserva: consumirReserva,
      ),
    );
    return r.efetiva;
  }

  /// Reserva `min(desejada, disponível)` e retorna o que reservou.
  Future<double> reservar({
    required String materialId,
    required double quantidadeDesejada,
    required String listaCorteId,
    String? clienteNome,
    String? projetoNome,
    String motivo = 'Lista de corte',
  }) async {
    final r = await _movimentar(
      materialId: materialId,
      tipo: TipoMovimentacao.reserva,
      origem: OrigemMovimentacao.listaCorte,
      motivo: motivo,
      clienteNome: clienteNome,
      projetoNome: projetoNome,
      listaCorteId: listaCorteId,
      calcular: (c, u) => c.reservar(arredondarParaUnidade(quantidadeDesejada, u)),
    );
    return r.efetiva;
  }

  Future<double> liberarReserva({
    required String materialId,
    required double quantidade,
    String? listaCorteId,
    String motivo = 'Lista cancelada',
    String? clienteNome,
    String? projetoNome,
    OrigemMovimentacao origem = OrigemMovimentacao.listaCorte,
  }) async {
    final r = await _movimentar(
      materialId: materialId,
      tipo: TipoMovimentacao.liberacaoReserva,
      origem: origem,
      motivo: motivo,
      clienteNome: clienteNome,
      projetoNome: projetoNome,
      listaCorteId: listaCorteId,
      calcular: (c, u) => c.liberar(quantidade),
    );
    return r.efetiva;
  }

  /// Inventário: grava um `ajuste` com a diferença pro [novoFisico].
  Future<void> ajustar({
    required String materialId,
    required double novoFisico,
    String motivo = 'Inventário',
    OrigemMovimentacao origem = OrigemMovimentacao.manual,
  }) async {
    await _movimentar(
      materialId: materialId,
      tipo: TipoMovimentacao.ajuste,
      origem: origem,
      motivo: motivo,
      calcular: (c, u) => c.ajustar(arredondarParaUnidade(novoFisico, u)),
    );
  }

  Future<double> perda({
    required String materialId,
    required double quantidade,
    required String motivo,
    String? clienteNome,
    String? projetoNome,
    OrigemMovimentacao origem = OrigemMovimentacao.manual,
  }) async {
    final r = await _movimentar(
      materialId: materialId,
      tipo: TipoMovimentacao.perda,
      origem: origem,
      motivo: motivo,
      clienteNome: clienteNome,
      projetoNome: projetoNome,
      calcular: (c, u) => c.saida(arredondarParaUnidade(quantidade, u)),
    );
    return r.efetiva;
  }

  /// Material novo vindo de lista/nota: nasce com estoque 0, então cai como
  /// falta e vai pro pedido. Nunca trava o fluxo.
  Future<String> criarMaterialAutomatico({
    required String descricaoOriginal,
    CategoriaMaterial? categoria,
    UnidadeEstoque? unidade,
    String? refFornecedor,
    double? espessuraMm,
    double? larguraMm,
    double? alturaMm,
    String? fornecedorId,
    String? origemCriacao,
  }) async {
    final cat = categoria ?? inferirCategoria(descricaoOriginal);
    final espessura =
        espessuraMm ??
        (cat == CategoriaMaterial.chapa || cat == CategoriaMaterial.fita
            ? medidasMm(descricaoOriginal).where((m) => m <= 60).firstOrNull
            : null);
    final material = MaterialEstoque(
      id: '',
      nome: nomeLegivel(descricaoOriginal),
      categoria: cat,
      unidade: unidade ?? unidadePadrao(cat),
      espessuraMm: espessura,
      larguraMm: larguraMm,
      alturaMm: alturaMm,
      refFornecedor: refFornecedor,
      fornecedorId: fornecedorId,
      apelidos: [normalizar(descricaoOriginal)],
      criadoAutomaticamente: true,
      origemCriacao: origemCriacao,
    );
    final ref = _materiais.doc();
    await ref.set({
      ...material.toMap(),
      'criadoEm': FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ------------------------------------------------------------ comprovante

  /// Retirada ou entrada de um ou mais materiais com comprovante numerado.
  /// Uma transação só: grava saldos, movimentações, comprovante e o
  /// contador juntos, ou nada. Diferente das outras operações, aqui o que
  /// não cabe **lança** (o comprovante tem que dizer a verdade): retirada
  /// maior que o físico pede uma contagem antes.
  Future<Comprovante> registrarComprovante({
    required TipoComprovante tipo,
    required List<ItemPedidoComprovante> itens,
    required String motivo,
    String? recebedorNome,
    String? recebedorFuncao,
    String? origemNome,
    String? notaNumero,
    String? clienteNome,
    String? projetoNome,
    String? listaCorteId,
    String? observacao,
    String? assinaturaPng,
    String? registradoNo,
  }) async {
    String? t(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
    final recebedor = t(recebedorNome);
    if (tipo == TipoComprovante.retirada && recebedor == null) {
      throw const EstoqueException('Informe para quem o material foi entregue.');
    }
    // Mesmo material duas vezes vira uma linha só, na ordem da primeira.
    final pedidos = <String, ItemPedidoComprovante>{};
    for (final i in itens) {
      final antes = pedidos[i.materialId];
      pedidos[i.materialId] = antes == null
          ? i
          : ItemPedidoComprovante(i.materialId, antes.quantidade + i.quantidade, custoUnitario: i.custoUnitario ?? antes.custoUnitario);
    }
    if (pedidos.isEmpty) throw const EstoqueException('Escolha pelo menos um material.');

    final resp = await responsavelAtual();
    final contadorRef = _db.collection('contadores').doc('comprovantes');
    final compRef = _db.collection('comprovantes').doc();
    final tipoMov = tipo.movimentacao;
    final depois = <MaterialEstoque>[];
    final alertas = <String>[];

    final comprovante = await _db.runTransaction<Comprovante>((tx) async {
      // Firestore: todas as leituras antes de qualquer escrita.
      final contador = await tx.get(contadorRef);
      final snaps = [for (final id in pedidos.keys) await tx.get(_materiais.doc(id))];
      final numero = lerNum(contador.data()?['ultimo']).toInt() + 1;
      depois.clear();
      alertas.clear();
      final linhas = <ItemComprovante>[];
      final escritas = <void Function()>[];

      for (final snap in snaps) {
        if (!snap.exists) throw EstoqueException('Material ${snap.id} não encontrado.');
        final m = MaterialEstoque.fromFirestore(snap);
        final pedido = pedidos[m.id]!;
        final q = arredondarParaUnidade(pedido.quantidade, m.unidade);
        if (q <= 0) throw EstoqueException('${m.nome}: a quantidade precisa ser maior que zero.');
        if (tipo == TipoComprovante.retirada && q > m.estoqueFisico) {
          throw EstoqueException(
            '${m.nome}: retirada de ${fmtQtd(q, m.unidade)} é maior que o físico '
            '(${fmtQtd(m.estoqueFisico, m.unidade)}). Faça a contagem antes.',
          );
        }
        final calc = CalculoSaldo(
          fisico: m.estoqueFisico,
          reservado: m.estoqueReservado,
          custoMedio: m.custoMedio,
          unidade: m.unidade,
        );
        final novo = tipo == TipoComprovante.retirada
            ? calc.saida(q)
            : calc.entrada(q, custoUnitario: pedido.custoUnitario);
        if (novo.alerta != null) alertas.add('${m.nome}: ${novo.alerta}');

        final movRef = _movs.doc();
        final mov = Movimentacao(
          id: movRef.id,
          materialId: m.id,
          materialNome: m.nome,
          tipo: tipoMov,
          quantidade: novo.efetiva,
          sinal: novo.sinal,
          unidade: m.unidade,
          motivo: motivo,
          clienteNome: t(clienteNome),
          projetoNome: t(projetoNome),
          fornecedorNome: tipo == TipoComprovante.entrada ? t(origemNome) : null,
          listaCorteId: listaCorteId,
          recebedorNome: recebedor,
          comprovanteId: compRef.id,
          comprovanteNumero: numero,
          origem: OrigemMovimentacao.manual,
          responsavelId: resp.id,
          responsavelNome: resp.nome,
          fisicoAntes: m.estoqueFisico,
          fisicoDepois: novo.fisico,
          reservadoAntes: m.estoqueReservado,
          reservadoDepois: novo.reservado,
        );
        escritas.add(() {
          tx.update(snap.reference, {
            'estoqueFisico': novo.fisico,
            'estoqueReservado': novo.reservado,
            'custoMedio': novo.custoMedio,
            'atualizadoEm': FieldValue.serverTimestamp(),
          });
          tx.set(movRef, {...mov.toMap(), 'criadoEm': FieldValue.serverTimestamp()});
        });
        linhas.add(ItemComprovante(
          materialId: m.id,
          materialNome: m.nome,
          quantidade: novo.efetiva,
          unidade: m.unidade,
          local: m.local,
          fisicoAntes: m.estoqueFisico,
          fisicoDepois: novo.fisico,
          movimentacaoId: movRef.id,
        ));
        depois.add(m.copyWith(
          estoqueFisico: novo.fisico,
          estoqueReservado: novo.reservado,
          custoMedio: novo.custoMedio,
        ));
      }

      final c = Comprovante(
        id: compRef.id,
        numero: numero,
        tipo: tipo,
        itens: linhas,
        recebedorNome: recebedor,
        recebedorFuncao: t(recebedorFuncao),
        origemNome: t(origemNome),
        notaNumero: t(notaNumero),
        clienteNome: t(clienteNome),
        projetoNome: t(projetoNome),
        listaCorteId: listaCorteId,
        motivo: motivo,
        observacao: t(observacao),
        responsavelId: resp.id,
        responsavelNome: resp.nome,
        assinaturaPng: assinaturaPng,
        registradoNo: registradoNo,
      );
      for (final e in escritas) {
        e();
      }
      tx.set(compRef, {...c.toMap(), 'criadoEm': FieldValue.serverTimestamp()});
      tx.set(contadorRef, {'ultimo': numero}, SetOptions(merge: true));
      return c;
    });

    for (final a in alertas) {
      await AvisoService(db: _db).registrar(TipoAviso.alerta, a, listaCorteId: listaCorteId);
    }
    for (final m in depois) {
      for (final ouvinte in List.of(ouvintes)) {
        try {
          await ouvinte(m, tipoMov);
        } catch (e) {
          debugPrint('Ouvinte de saldo falhou: $e');
        }
      }
    }
    return comprovante.copyWith(criadoEm: DateTime.now());
  }

  // ------------------------------------------------------------------ núcleo

  Future<_Resultado> _movimentar({
    required String materialId,
    required TipoMovimentacao tipo,
    required OrigemMovimentacao origem,
    required String motivo,
    required NovoSaldo Function(CalculoSaldo calc, UnidadeEstoque u) calcular,
    String? clienteNome,
    String? projetoNome,
    String? fornecedorNome,
    String? listaCorteId,
    String? notaFiscalId,
    String? pedidoId,
  }) async {
    final resp = await responsavelAtual();
    final ref = _materiais.doc(materialId);

    final resultado = await _db.runTransaction<_Resultado>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw EstoqueException('Material $materialId não encontrado.');
      }
      final m = MaterialEstoque.fromFirestore(snap);
      final calc = CalculoSaldo(
        fisico: m.estoqueFisico,
        reservado: m.estoqueReservado,
        custoMedio: m.custoMedio,
        unidade: m.unidade,
      );
      final novo = calcular(calc, m.unidade);
      final depois = m.copyWith(
        estoqueFisico: novo.fisico,
        estoqueReservado: novo.reservado,
        custoMedio: novo.custoMedio,
      );
      // Nada a movimentar (ex.: reservar com disponível 0): não grava nada.
      if (novo.efetiva <= 0) {
        return _Resultado(null, 0, depois, novo.alerta);
      }

      tx.update(ref, {
        'estoqueFisico': novo.fisico,
        'estoqueReservado': novo.reservado,
        'custoMedio': novo.custoMedio,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      final movRef = _movs.doc();
      final mov = Movimentacao(
        id: movRef.id,
        materialId: m.id,
        materialNome: m.nome,
        tipo: tipo,
        quantidade: novo.efetiva,
        sinal: novo.sinal,
        unidade: m.unidade,
        motivo: motivo,
        clienteNome: clienteNome,
        projetoNome: projetoNome,
        fornecedorNome: fornecedorNome,
        listaCorteId: listaCorteId,
        notaFiscalId: notaFiscalId,
        pedidoId: pedidoId,
        origem: origem,
        responsavelId: resp.id,
        responsavelNome: resp.nome,
        fisicoAntes: m.estoqueFisico,
        fisicoDepois: novo.fisico,
        reservadoAntes: m.estoqueReservado,
        reservadoDepois: novo.reservado,
      );
      tx.set(movRef, {
        ...mov.toMap(),
        'criadoEm': FieldValue.serverTimestamp(),
      });
      return _Resultado(movRef.id, novo.efetiva, depois, novo.alerta);
    });

    if (resultado.alerta != null) {
      await AvisoService(db: _db).registrar(
        TipoAviso.alerta,
        '${resultado.material.nome}: ${resultado.alerta}',
        listaCorteId: listaCorteId,
      );
    }
    if (resultado.movimentacaoId != null) {
      for (final ouvinte in List.of(ouvintes)) {
        try {
          await ouvinte(resultado.material, tipo);
        } catch (e) {
          debugPrint('Ouvinte de saldo falhou: $e');
        }
      }
    }
    return resultado;
  }
}

class _Resultado {
  final String? movimentacaoId;
  final double efetiva;
  final MaterialEstoque material;
  final String? alerta;
  const _Resultado(this.movimentacaoId, this.efetiva, this.material, this.alerta);
}
