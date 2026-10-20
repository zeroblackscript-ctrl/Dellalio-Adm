import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../importacao/arquivo_entrada.dart';
import '../importacao/canal_ia.dart';
import '../importacao/conversor_unidades.dart';
import '../models/models.dart';
import '../services/aviso_service.dart';
import '../services/casamento_service.dart';
import '../services/estoque_service.dart';
import '../services/pedido_service.dart';
import '../services/score_casamento.dart';
import '../util/normalizar.dart';
import '../util/quantidade.dart';
import 'nota_lida.dart';

/// Entrada automática por nota fiscal: XML da NF-e (principal), DANFE em
/// PDF ou foto (pela IA). Cada item casado vira `registrarRecebimento`, que
/// dá entrada, atualiza o custo médio e realoca as listas que esperavam.
class ImportadorNotas {
  ImportadorNotas({FirebaseFirestore? db, CanalIA? ia, EstoqueService? estoque})
    : _db = db ?? FirebaseFirestore.instance,
      _ia = ia,
      _estoque = estoque;

  static final ImportadorNotas instancia = ImportadorNotas();

  final FirebaseFirestore _db;
  final CanalIA? _ia;
  final EstoqueService? _estoque;

  CanalIA get _canal => _ia ?? CanalIA.padrao;
  EstoqueService get _est => _estoque ?? EstoqueService.sistema(db: _db);
  CollectionReference<Map<String, dynamic>> get _notas => _db.collection('notas_fiscais');

  /// O arquivo é uma nota? (XML de NF-e, PDF com "DANFE", ou foto)
  static bool ehNota(String nome, Uint8List bytes) {
    final ext = p.extension(nome).toLowerCase();
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png') return true;
    if (ext == '.xml') return pareceXmlNfe(utf8.decode(bytes, allowMalformed: true));
    if (ext == '.pdf') {
      final (texto, _) = extrairTextoPdf(bytes);
      return normalizar(texto).contains('danfe');
    }
    return false;
  }

  Future<String?> importar(File arquivo) async =>
      importarBytes(p.basename(arquivo.path), await arquivo.readAsBytes());

  /// Retorna o id da nota, ou `null` se ela já tinha entrado.
  Future<String?> importarBytes(String nome, Uint8List bytes) async {
    final lida = await ler(nome, bytes);
    final id = lida.idDocumento;
    if (id == null) {
      await AvisoService(db: _db).registrar(
        TipoAviso.alerta,
        'Nota "$nome" sem chave de acesso nem CNPJ/número legíveis. Confira o arquivo.',
      );
      return null;
    }

    // Reserva o id antes de lançar: o mesmo XML duas vezes não duplica.
    final ref = _notas.doc(id);
    final nova = await _db.runTransaction<bool>((tx) async {
      if ((await tx.get(ref)).exists) return false;
      tx.set(ref, {
        ...NotaFiscal(
          id: id,
          chaveAcesso: lida.chaveAcesso,
          fornecedorNome: lida.nomeEmitente,
          cnpjEmitente: lida.cnpjEmitente,
          numero: lida.numero,
          emitidaEm: lida.emitidaEm,
          arquivoNome: nome,
        ).toMap(),
        'criadoEm': FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (!nova) return null;

    final fornecedor = await _fornecedor(lida);
    final itens = await _casarItens(lida, fornecedor);

    final esperando = await _listasEsperando();
    final lancados = await _lancar(id, fornecedor, itens);
    final status = lancados.any((i) => i.situacao == SituacaoItemNota.confirmar)
        ? StatusNota.parcial
        : StatusNota.lancada;
    await ref.update({
      'fornecedorId': fornecedor.id,
      'fornecedorNome': fornecedor.nome,
      'itens': lancados.map((i) => i.toMap()).toList(),
      'status': status.name,
      'movimentacaoIds': lancados.map((i) => i.movimentacaoId).whereType<String>().toList(),
    });
    await _avisar(lida.numero, fornecedor.nome, lancados, esperando, id);
    return id;
  }

  Future<NotaLida> ler(String nome, Uint8List bytes) async {
    final ext = p.extension(nome).toLowerCase();
    if (ext == '.xml') return lerXmlNfe(utf8.decode(bytes, allowMalformed: true));
    final mime = switch (ext) {
      '.pdf' => 'application/pdf',
      '.png' => 'image/png',
      _ => 'image/jpeg',
    };
    return notaDoJson(await _canal.lerNota(bytes, mime));
  }

  // ------------------------------------------------------- fornecedor

  /// Acha pelo CNPJ ou cria.
  Future<Fornecedor> _fornecedor(NotaLida n) async {
    final col = _db.collection('fornecedores');
    if (n.cnpjEmitente != null) {
      final s = await col.where('cnpj', isEqualTo: n.cnpjEmitente).limit(1).get();
      if (s.docs.isNotEmpty) return Fornecedor.fromFirestore(s.docs.first);
    }
    final porNome = await col.get();
    for (final d in porNome.docs) {
      if (normalizar((d.data()['nome'] ?? '').toString()) == normalizar(n.nomeEmitente)) {
        final f = Fornecedor.fromFirestore(d);
        if (f.cnpj == null && n.cnpjEmitente != null) {
          await d.reference.update({'cnpj': n.cnpjEmitente});
        }
        return f;
      }
    }
    final fone = (n.foneEmitente ?? '').replaceAll(RegExp(r'\D'), '');
    final f = Fornecedor(
      id: '',
      nome: nomeLegivel(n.nomeEmitente),
      cnpj: n.cnpjEmitente,
      // Telefone da nota vira o WhatsApp sugerido (55 + DDD + número).
      whatsapp: fone.length >= 10 ? '55$fone' : null,
    );
    final ref = await col.add(f.toMap());
    return Fornecedor.fromMap(ref.id, f.toMap());
  }

  // -------------------------------------------------------- casamento

  Future<List<ItemNota>> _casarItens(NotaLida n, Fornecedor f) async {
    final materiais = (await _db.collection('materiais').get()).docs.map(MaterialEstoque.fromFirestore).toList();
    final doFornecedor = materiais.where((m) => m.fornecedorId == f.id).toList();
    final porId = {for (final m in materiais) m.id: m};

    final itens = <ItemNota>[];
    final ambiguos = <int, List<Candidato>>{};
    for (var i = 0; i < n.itens.length; i++) {
      final it = n.itens[i];
      var item = ItemNota(
        codigo: it.codigo,
        ean: it.ean,
        descricao: it.descricao,
        quantidade: it.quantidade,
        unidadeComercial: it.unidade.toUpperCase(),
        valorUnitario: it.valorUnitario,
      );
      MaterialEstoque? m;
      MetodoCasamento? metodo;
      // 1. Código aprendido das notas anteriores desse fornecedor.
      final aprendido = f.codigosProduto[it.codigo];
      if (aprendido != null && porId[aprendido]?.ativo == true) {
        m = porId[aprendido];
        metodo = MetodoCasamento.ref;
      }
      // 2. Pipeline da etapa 03, primeiro só com os materiais do fornecedor.
      m ??= porReferencia(it.codigo, doFornecedor) ?? porReferencia(it.ean, materiais);
      if (m != null) metodo ??= MetodoCasamento.ref;
      if (m == null) {
        m = porApelido(it.descricao, doFornecedor) ?? porApelido(it.descricao, materiais);
        if (m != null) metodo = MetodoCasamento.apelido;
      }
      if (m == null) {
        final alvo = AlvoCasamento(
          descricao: it.descricao,
          categoria: inferirCategoria(it.descricao),
          fornecedorId: f.id,
        );
        var cands = rankear(alvo, doFornecedor);
        if (cands.isEmpty || cands.first.score < CasamentoService.aceite) {
          cands = rankear(alvo, materiais);
        }
        final melhor = cands.firstOrNull;
        if (melhor != null && melhor.score >= CasamentoService.aceite) {
          m = melhor.material;
          metodo = MetodoCasamento.aproximado;
        } else if (melhor != null && melhor.score >= CasamentoService.minimoParecido) {
          ambiguos[i] = cands;
        }
      }
      if (m != null) item = item.copyWith(materialId: m.id, materialNome: m.nome, metodo: metodo);
      itens.add(item);
    }

    // IA de desempate, uma chamada pela nota toda.
    if (ambiguos.isNotEmpty) {
      Map<int, (String?, double)> resp = const {};
      try {
        final r = await _canal.desempatar([
          for (final e in ambiguos.entries)
            {
              'indice': e.key,
              'descricao': n.itens[e.key].descricao,
              'candidatos': [for (final c in e.value.take(5)) {'materialId': c.material.id, 'nome': c.material.nome}],
            },
        ]);
        resp = {
          for (final x in r)
            if (x['indice'] is num) (x['indice'] as num).toInt(): (x['materialId'] as String?, (x['confianca'] as num?)?.toDouble() ?? 0),
        };
      } catch (e) {
        debugPrint('Desempate da nota indisponível: $e');
      }
      for (final e in ambiguos.entries) {
        final r = resp[e.key];
        final m = r == null ? null : e.value.where((c) => c.material.id == r.$1).firstOrNull?.material;
        if (m != null && r!.$2 >= CasamentoService.aceite) {
          itens[e.key] = itens[e.key].copyWith(materialId: m.id, materialNome: m.nome, metodo: MetodoCasamento.ia);
        } else {
          itens[e.key] = itens[e.key].copyWith(
            materialId: e.value.first.material.id,
            materialNome: e.value.first.material.nome,
            situacao: SituacaoItemNota.confirmar,
            pergunta: 'É ${e.value.first.material.nome}?',
          );
        }
      }
    }

    // 4. Sem correspondência: cria o material (já com o fornecedor).
    for (var i = 0; i < itens.length; i++) {
      if (itens[i].materialId != null) continue;
      final it = itens[i];
      final cat = inferirCategoria(it.descricao);
      final id = await _est.criarMaterialAutomatico(
        descricaoOriginal: it.descricao,
        categoria: cat,
        unidade: ConversorUnidades.unidadeParaNovo(it.unidadeComercial, cat),
        refFornecedor: it.codigo.isEmpty ? null : it.codigo,
        fornecedorId: f.id,
        origemCriacao: 'criado pela nota de ${f.nome}',
      );
      final m = MaterialEstoque.fromFirestore(await _db.collection('materiais').doc(id).get());
      porId[id] = m;
      itens[i] = it.copyWith(materialId: id, materialNome: m.nome, metodo: MetodoCasamento.criado);
    }

    // Conversão de unidade e aprendizado.
    final codigos = <String, String>{};
    for (var i = 0; i < itens.length; i++) {
      final it = itens[i];
      // Sem método = ambíguo ("É X?"): espera o usuário.
      if (it.metodo == null || it.materialId == null) continue;
      final m = porId[it.materialId!] ??
          MaterialEstoque.fromFirestore(await _db.collection('materiais').doc(it.materialId).get());
      itens[i] = converter(it, m);
      if (it.codigo.isNotEmpty) codigos[it.codigo] = m.id;
      await _aprender(it, m, f);
    }
    if (codigos.isNotEmpty) {
      await _db.collection('fornecedores').doc(f.id).set({
        'codigosProduto': codigos,
      }, SetOptions(merge: true));
    }
    return itens;
  }

  /// `uCom` → unidade do estoque. Embalagem sem fator conhecido (CX, PCT,
  /// RL...) vira pergunta, respondida uma vez e guardada no material.
  static ItemNota converter(ItemNota it, MaterialEstoque m) {
    final fator = m.fatorEmbalagem[it.unidadeComercial];
    if (fator != null && fator > 0) {
      return it.copyWith(
        quantidadeEstoque: arredondarParaUnidade(it.quantidade * fator, m.unidade),
        situacao: SituacaoItemNota.lancado,
        limparPergunta: true,
      );
    }
    final c = ConversorUnidades.paraUnidadeDoEstoque(
      quantidade: it.quantidade,
      unidadeOriginal: it.unidadeComercial,
      material: m,
    );
    if (c.desconhecida) {
      return it.copyWith(
        situacao: SituacaoItemNota.confirmar,
        pergunta: 'Quantos ${m.unidade.sigla} vêm em 1 ${it.unidadeComercial}?',
      );
    }
    return it.copyWith(
      quantidadeEstoque: c.quantidade,
      situacao: SituacaoItemNota.lancado,
      limparPergunta: true,
    );
  }

  Future<void> _aprender(ItemNota it, MaterialEstoque m, Fornecedor f) async {
    final campos = <String, Object>{};
    final apelido = normalizar(it.descricao);
    if (!m.apelidos.contains(apelido)) campos['apelidos'] = FieldValue.arrayUnion([apelido]);
    if (m.fornecedorId == null) campos['fornecedorId'] = f.id;
    if (m.refFornecedor == null && it.codigo.isNotEmpty && (m.fornecedorId ?? f.id) == f.id) {
      campos['refFornecedor'] = it.codigo;
    }
    if (campos.isNotEmpty) await _db.collection('materiais').doc(m.id).update(campos);
  }

  // ----------------------------------------------------------- lançar

  Future<List<ItemNota>> _lancar(String notaId, Fornecedor f, List<ItemNota> itens) async {
    final pedidos = PedidoService(db: _db, estoque: _est);
    final saida = <ItemNota>[];
    for (final it in itens) {
      if (it.situacao != SituacaoItemNota.lancado || it.movimentacaoId != null) {
        saida.add(it);
        continue;
      }
      try {
        saida.add(it.copyWith(movimentacaoId: await _registrar(pedidos, notaId, f, it)));
      } catch (e) {
        debugPrint('Entrada falhou (${it.descricao}): $e');
        saida.add(it.copyWith(situacao: SituacaoItemNota.confirmar, pergunta: 'Entrada falhou; tente de novo.'));
      }
    }
    return saida;
  }

  Future<String?> _registrar(PedidoService pedidos, String notaId, Fornecedor f, ItemNota it) {
    final q = it.quantidadeEstoque ?? it.quantidade;
    // Custo por unidade do estoque (vUnCom é por unidade comercial).
    final custo = q > 0 ? it.valorUnitario * it.quantidade / q : null;
    return pedidos.registrarRecebimento(
      materialId: it.materialId!,
      quantidade: q,
      custoUnitario: custo,
      fornecedorId: f.id,
      fornecedorNome: f.nome,
      notaFiscalId: notaId,
    );
  }

  /// Resposta à pergunta da embalagem: guarda no material e lança o item.
  Future<void> responderEmbalagem(String notaId, int indice, double fator) async {
    final nota = NotaFiscal.fromFirestore(await _notas.doc(notaId).get());
    final it = nota.itens[indice];
    await _db.collection('materiais').doc(it.materialId).update({
      'fatorEmbalagem.${it.unidadeComercial}': fator,
    });
    await _confirmar(nota, indice, it.materialId!);
  }

  /// "É `material`?" → Sim ou escolheu outro.
  Future<void> confirmarItem(String notaId, int indice, String materialId) async {
    final nota = NotaFiscal.fromFirestore(await _notas.doc(notaId).get());
    final f = Fornecedor.fromFirestore(await _db.collection('fornecedores').doc(nota.fornecedorId).get());
    if (nota.itens[indice].codigo.isNotEmpty) {
      await _db.collection('fornecedores').doc(f.id).set({
        'codigosProduto': {nota.itens[indice].codigo: materialId},
      }, SetOptions(merge: true));
    }
    await _confirmar(nota, indice, materialId);
  }

  Future<void> _confirmar(NotaFiscal nota, int indice, String materialId) async {
    final m = MaterialEstoque.fromFirestore(await _db.collection('materiais').doc(materialId).get());
    final f = Fornecedor.fromFirestore(await _db.collection('fornecedores').doc(nota.fornecedorId).get());
    var it = converter(nota.itens[indice].copyWith(materialId: m.id, materialNome: m.nome, metodo: MetodoCasamento.manual), m);
    await _aprender(it, m, f);
    if (it.situacao == SituacaoItemNota.lancado) {
      it = it.copyWith(movimentacaoId: await _registrar(PedidoService(db: _db, estoque: _est), nota.id, f, it));
    }
    final itens = List.of(nota.itens)..[indice] = it;
    await _notas.doc(nota.id).update({
      'itens': itens.map((i) => i.toMap()).toList(),
      'status': (itens.any((i) => i.situacao == SituacaoItemNota.confirmar) ? StatusNota.parcial : StatusNota.lancada).name,
      'movimentacaoIds': itens.map((i) => i.movimentacaoId).whereType<String>().toList(),
    });
  }

  // ------------------------------------------------------------ aviso

  Future<Set<String>> _listasEsperando() async {
    final s = await _db.collection('listas_corte').where('status', isEqualTo: StatusLista.aguardandoCompra.name).get();
    return s.docs.map((d) => d.id).toSet();
  }

  /// "NF 48213 de Leo Madeiras: 4 itens lançados. Cozinha Rodrigues agora
  /// está pronta para cortar."
  Future<void> _avisar(String numero, String fornecedor, List<ItemNota> itens, Set<String> esperando, String notaId) async {
    final n = itens.where((i) => i.situacao == SituacaoItemNota.lancado).length;
    final pendentes = itens.length - n;
    final prontas = <String>[];
    for (final id in esperando) {
      final l = ListaCorte.fromFirestore(await _db.collection('listas_corte').doc(id).get());
      if (l.status == StatusLista.pronta) prontas.add(l.titulo);
    }
    final b = StringBuffer('NF $numero de $fornecedor: $n ${n == 1 ? 'item lançado' : 'itens lançados'}.');
    if (pendentes > 0) b.write(' $pendentes ${pendentes == 1 ? 'precisa' : 'precisam'} de confirmação.');
    if (prontas.isNotEmpty) {
      b.write(' ${prontas.join(', ')} agora ${prontas.length == 1 ? 'está pronta' : 'estão prontas'} para cortar.');
    }
    await AvisoService(db: _db).registrar(TipoAviso.notaLancada, b.toString(), notaFiscalId: notaId);
  }
}
