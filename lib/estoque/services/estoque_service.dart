import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

  Future<Responsavel> _responsavel() async =>
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
    final resp = await _responsavel();
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
