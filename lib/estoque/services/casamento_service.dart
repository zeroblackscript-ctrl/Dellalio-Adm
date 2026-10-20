import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../importacao/canal_ia.dart';
import '../importacao/conversor_unidades.dart';
import '../models/models.dart';
import '../util/normalizar.dart';
import '../util/quantidade.dart';
import 'aviso_service.dart';
import 'estoque_service.dart';
import 'reserva_service.dart';
import 'score_casamento.dart';

/// Casamento automático item → material, depois reserva e pedido.
///
/// Ordem, parando no primeiro que resolver:
/// 1. referência do fornecedor (1,0) · 2. apelido (0,98) ·
/// 3. aproximado ≥ 0,85 · 4. IA de desempate (0,60–0,85, uma chamada por
/// lista) · 5. nada parecido (< 0,60) → cria material novo.
/// Abaixo de 0,85 na IA o item vai pra `confirmar` com sugestões.
class CasamentoService {
  CasamentoService({FirebaseFirestore? db, CanalIA? ia, EstoqueService? estoque})
    : _db = db ?? FirebaseFirestore.instance,
      _ia = ia,
      _estoque = estoque;

  final FirebaseFirestore _db;
  final CanalIA? _ia;
  final EstoqueService? _estoque;

  static const double aceite = 0.85;
  static const double minimoParecido = 0.60;

  /// Chamado pelo importador assim que a lista é gravada.
  static Future<void> processar(String listaId) =>
      CasamentoService().processarLista(listaId);

  EstoqueService get _est => _estoque ?? EstoqueService.sistema(db: _db);
  CanalIA get _canal => _ia ?? CanalIA.padrao;

  Future<List<MaterialEstoque>> _materiais() async {
    final s = await _db.collection('materiais').get();
    return s.docs.map(MaterialEstoque.fromFirestore).toList();
  }

  Future<Map<String, String>> _fornecedoresPorNome() async {
    final s = await _db.collection('fornecedores').get();
    return {for (final d in s.docs) normalizar((d.data()['nome'] ?? '').toString()): d.id};
  }

  Future<void> processarLista(String listaId) async {
    final ref = _db.collection('listas_corte').doc(listaId);
    final lista = ListaCorte.fromFirestore(await ref.get());
    if (lista.status != StatusLista.lida || lista.itens.isEmpty) return;

    final materiais = await _materiais();
    final fornecedores = await _fornecedoresPorNome();
    final itens = List.of(lista.itens);

    // Passos 1–3, e separa os ambíguos pra IA.
    final ambiguos = <int, List<Candidato>>{};
    final criar = <int>[];
    final aprender = <int, MaterialEstoque>{};
    for (var i = 0; i < itens.length; i++) {
      final it = itens[i];
      if (it.materialId != null) continue;
      final alvo = AlvoCasamento(
        descricao: it.descricaoOriginal,
        refFornecedor: it.refFornecedor,
        categoria: it.categoria,
        espessuraMm: it.espessuraMm,
        fornecedorId: it.fornecedorNome == null ? null : fornecedores[normalizar(it.fornecedorNome!)],
      );
      final porRef = porReferencia(it.refFornecedor, materiais);
      if (porRef != null) {
        itens[i] = aplicarMaterial(it, porRef, MetodoCasamento.ref, 1.0);
        continue;
      }
      final porApel = porApelido(it.descricaoOriginal, materiais);
      if (porApel != null) {
        itens[i] = aplicarMaterial(it, porApel, MetodoCasamento.apelido, 0.98);
        aprender[i] = porApel; // grava a ref se o item trouxe e o material não
        continue;
      }
      final cands = rankear(alvo, materiais);
      final melhor = cands.firstOrNull;
      if (melhor != null && melhor.score >= aceite) {
        itens[i] = aplicarMaterial(it, melhor.material, MetodoCasamento.aproximado, melhor.score);
        aprender[i] = melhor.material;
      } else if (melhor != null && melhor.score >= minimoParecido) {
        ambiguos[i] = cands;
      } else {
        criar.add(i);
      }
    }

    // Passo 4: IA, uma chamada só pra todos os ambíguos.
    if (ambiguos.isNotEmpty) {
      final respostas = await _desempatar(itens, ambiguos);
      for (final e in ambiguos.entries) {
        final i = e.key;
        final r = respostas[i];
        final escolhido = r == null
            ? null
            : e.value.where((c) => c.material.id == r.$1).firstOrNull?.material;
        if (escolhido != null && r!.$2 >= aceite) {
          itens[i] = aplicarMaterial(itens[i], escolhido, MetodoCasamento.ia, r.$2);
          aprender[i] = escolhido;
        } else {
          itens[i] = paraConfirmar(itens[i], e.value);
        }
      }
    }

    // Passo 5: material novo (o mesmo texto repetido na lista vira um só).
    final criadosPorTexto = <String, MaterialEstoque>{};
    for (final i in criar) {
      final it = itens[i];
      final chave = normalizar(it.descricaoOriginal);
      var m = criadosPorTexto[chave];
      if (m == null) {
        try {
          m = await _criarMaterial(it, lista, fornecedores);
          criadosPorTexto[chave] = m;
          materiais.add(m);
        } catch (e) {
          debugPrint('Não criou material pra ${it.descricaoOriginal}: $e');
          itens[i] = it.copyWith(situacao: SituacaoItem.confirmar);
          continue;
        }
      }
      itens[i] = aplicarMaterial(it, m, MetodoCasamento.criado, 1.0);
    }

    for (final e in aprender.entries) {
      await aprenderCom(itens[e.key], e.value);
    }

    // Grava o casamento e reserva.
    final casada = lista.copyWith(itens: itens);
    await ref.update({
      'itens': itens.map((i) => i.toMap()).toList(),
      'resumo': casada.resumo.toMap(),
    });
    final reservada = await ReservaService(db: _db, estoque: _est).reservarLista(casada);
    await _avisarLeitura(reservada);
  }

  /// Usuário confirmou o item (Sim, escolheu outro, ou criou novo): roda
  /// casamento → reserva → pedido só pra ele, e aprende o apelido.
  Future<void> confirmarItem(
    String listaId,
    int indice,
    String materialId, {
    EstoqueService? estoque,
  }) async {
    final ref = _db.collection('listas_corte').doc(listaId);
    final lista = ListaCorte.fromFirestore(await ref.get());
    final snap = await _db.collection('materiais').doc(materialId).get();
    if (!snap.exists) throw const EstoqueException('Material não encontrado.');
    final m = MaterialEstoque.fromFirestore(snap);
    final it = lista.itens[indice];

    var novo = aplicarMaterial(it, m, MetodoCasamento.manual, 1.0);
    if (novo.situacao == SituacaoItem.confirmar) {
      // Unidade que não sei converter: o usuário aceitou, vale o número.
      novo = novo.copyWith(
        quantidade: arredondarParaUnidade(it.quantidadeOriginal, m.unidade),
        unidade: m.unidade,
        situacao: SituacaoItem.falta,
      );
    }
    await aprenderCom(novo, m);
    await _db.runTransaction((tx) async {
      final atual = ListaCorte.fromFirestore(await tx.get(ref));
      final itens = List.of(atual.itens)..[indice] = novo;
      tx.update(ref, {
        'itens': itens.map((i) => i.toMap()).toList(),
        'resumo': atual.copyWith(itens: itens).resumo.toMap(),
      });
    });
    final atual = ListaCorte.fromFirestore(await ref.get());
    await ReservaService(db: _db, estoque: estoque ?? _est).reservarLista(atual, indices: [indice]);
  }

  /// "Criar material novo" na tela de escolha.
  Future<void> confirmarComMaterialNovo(String listaId, int indice, {EstoqueService? estoque}) async {
    final lista = ListaCorte.fromFirestore(await _db.collection('listas_corte').doc(listaId).get());
    final m = await _criarMaterial(lista.itens[indice], lista, await _fornecedoresPorNome());
    await confirmarItem(listaId, indice, m.id, estoque: estoque);
  }

  // ------------------------------------------------------------- apoio

  /// Item casado com [m]: converte pra unidade do estoque. Unidade que não
  /// sei converter vai pra `confirmar`, com o material como sugestão.
  static ItemListaCorte aplicarMaterial(
    ItemListaCorte it,
    MaterialEstoque m,
    MetodoCasamento metodo,
    double confianca,
  ) {
    final c = ConversorUnidades.paraUnidadeDoEstoque(
      quantidade: it.quantidadeOriginal,
      unidadeOriginal: it.unidadeOriginal,
      larguraItemMm: it.larguraMm,
      alturaItemMm: it.alturaMm,
      material: m,
    );
    return it.copyWith(
      materialId: m.id,
      materialNome: m.nome,
      metodoCasamento: metodo,
      confianca: confianca,
      quantidade: c.quantidade,
      unidade: c.unidade,
      observacao: c.observacao,
      conferirConversao: c.conferir,
      sugestoes: c.desconhecida
          ? [SugestaoMaterial(materialId: m.id, nome: m.nome, score: confianca)]
          : const [],
      qtdReservada: 0,
      qtdFaltante: c.quantidade,
      situacao: c.desconhecida ? SituacaoItem.confirmar : SituacaoItem.falta,
    );
  }

  static ItemListaCorte paraConfirmar(ItemListaCorte it, List<Candidato> cands) =>
      it.copyWith(
        situacao: SituacaoItem.confirmar,
        confianca: cands.firstOrNull?.score ?? 0,
        sugestoes: [
          for (final c in cands.take(5))
            SugestaoMaterial(materialId: c.material.id, nome: c.material.nome, score: c.score),
        ],
        limparMaterial: true,
      );

  /// Aprendizado: guarda a descrição como apelido e a referência, se o
  /// material ainda não tinha. Na próxima lista casa no passo 1 ou 2.
  Future<void> aprenderCom(ItemListaCorte it, MaterialEstoque m) async {
    final apelido = normalizar(it.descricaoOriginal);
    final campos = <String, Object>{};
    if (apelido.isNotEmpty && !m.apelidos.contains(apelido)) {
      campos['apelidos'] = FieldValue.arrayUnion([apelido]);
    }
    if (it.refFornecedor != null && m.refFornecedor == null) {
      campos['refFornecedor'] = it.refFornecedor!;
    }
    if (campos.isEmpty) return;
    try {
      await _db.collection('materiais').doc(m.id).update(campos);
    } catch (e) {
      debugPrint('Aprendizado não gravado: $e');
    }
  }

  Future<MaterialEstoque> _criarMaterial(
    ItemListaCorte it,
    ListaCorte lista,
    Map<String, String> fornecedores,
  ) async {
    final cat = it.categoria ?? inferirCategoria(it.descricaoOriginal);
    final id = await _est.criarMaterialAutomatico(
      descricaoOriginal: it.descricaoOriginal,
      categoria: cat,
      unidade: ConversorUnidades.unidadeParaNovo(it.unidadeOriginal, cat),
      refFornecedor: it.refFornecedor,
      espessuraMm: it.espessuraMm,
      larguraMm: it.larguraMm,
      alturaMm: it.alturaMm,
      fornecedorId: it.fornecedorNome == null ? null : fornecedores[normalizar(it.fornecedorNome!)],
      origemCriacao: 'criado pela lista ${lista.titulo}',
    );
    return MaterialEstoque.fromFirestore(await _db.collection('materiais').doc(id).get());
  }

  /// índice → (materialId escolhido, confiança). IA fora do ar = vazio
  /// (os ambíguos vão pra confirmar; nada trava).
  Future<Map<int, (String?, double)>> _desempatar(
    List<ItemListaCorte> itens,
    Map<int, List<Candidato>> ambiguos,
  ) async {
    try {
      final respostas = await _canal.desempatar([
        for (final e in ambiguos.entries)
          {
            'indice': e.key,
            'descricao': itens[e.key].descricaoOriginal,
            'candidatos': [
              for (final c in e.value.take(5))
                {'materialId': c.material.id, 'nome': c.material.nome},
            ],
          },
      ]);
      return {
        for (final r in respostas)
          if (r['indice'] is num)
            (r['indice'] as num).toInt(): (
              r['materialId'] as String?,
              (r['confianca'] as num?)?.toDouble() ?? 0,
            ),
      };
    } catch (e) {
      debugPrint('Desempate pela IA indisponível: $e');
      return const {};
    }
  }

  Future<void> _avisarLeitura(ListaCorte l) async {
    final avisos = AvisoService(db: _db);
    final r = l.resumo;
    final emEstoque = r.ok;
    final noPedido = r.parcial + r.falta;
    await avisos.registrar(
      TipoAviso.listaLida,
      '${l.titulo} lida: $emEstoque de ${r.total} itens em estoque'
      '${noPedido > 0 ? ', $noPedido no pedido' : ''}.',
      listaCorteId: l.id,
    );
    if (r.confirmar > 0) {
      await avisos.registrar(
        TipoAviso.confirmar,
        '${r.confirmar} ${r.confirmar == 1 ? 'item precisa' : 'itens precisam'} '
        'de confirmação na lista ${l.titulo}.',
        listaCorteId: l.id,
      );
    }
    if (noPedido > 0) await _avisarPedidos(avisos);
  }

  /// "Madeireira Central: pedido pronto com 4 itens."
  Future<void> _avisarPedidos(AvisoService avisos) async {
    final s = await _db
        .collection('pedidos_compra')
        .where('status', isEqualTo: StatusPedido.rascunho.name)
        .get();
    for (final d in s.docs) {
      final p = PedidoCompra.fromFirestore(d);
      if (p.itens.isEmpty) continue;
      await avisos.registrar(
        TipoAviso.pedidoPronto,
        '${p.fornecedorNome}: pedido pronto com ${p.itens.length} '
        '${p.itens.length == 1 ? 'item' : 'itens'}.',
        pedidoId: p.id,
      );
    }
  }
}
