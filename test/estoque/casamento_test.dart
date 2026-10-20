import 'package:DELLALIO/estoque/importacao/canal_ia.dart';
import 'package:DELLALIO/estoque/models/models.dart';
import 'package:DELLALIO/estoque/services/casamento_service.dart';
import 'package:DELLALIO/estoque/services/estoque_service.dart';
import 'package:DELLALIO/estoque/services/lista_service.dart';
import 'package:DELLALIO/estoque/services/pedido_service.dart';
import 'package:DELLALIO/estoque/services/responsavel.dart';
import 'package:DELLALIO/estoque/services/score_casamento.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

MaterialEstoque _mat(
  String id,
  String nome, {
  CategoriaMaterial cat = CategoriaMaterial.chapa,
  UnidadeEstoque un = UnidadeEstoque.ch,
  double? esp,
  double fisico = 0,
  double minimo = 0,
  String? ref,
  String? fornecedorId,
  double? larg,
  double? alt,
}) => MaterialEstoque(
  id: id,
  nome: nome,
  categoria: cat,
  unidade: un,
  espessuraMm: esp,
  estoqueFisico: fisico,
  estoqueMinimo: minimo,
  refFornecedor: ref,
  fornecedorId: fornecedorId,
  larguraMm: larg,
  alturaMm: alt,
);

/// IA de desempate de mentira: escolhe o primeiro candidato com 0,9.
class _IAFake extends CanalIA {
  _IAFake({this.confianca = 0.9});
  final double confianca;
  int chamadas = 0;

  @override
  Future<List<Map<String, dynamic>>> desempatar(List<Map<String, dynamic>> itens) async {
    chamadas++;
    return [
      for (final i in itens)
        {
          'indice': i['indice'],
          'materialId': (i['candidatos'] as List).first['materialId'],
          'confianca': confianca,
        },
    ];
  }
}

ItemListaCorte _item(String desc, double q, String un, {String? ref, CategoriaMaterial? cat}) =>
    ItemListaCorte(
      descricaoOriginal: desc,
      quantidadeOriginal: q,
      unidadeOriginal: un,
      refFornecedor: ref,
      categoria: cat,
    );

void main() {
  group('score de casamento', () {
    final louro18 = _mat('l18', 'MDF Louro Freijó 18mm', esp: 18);

    test('mesma chapa escrita diferente passa de 0,85', () {
      final s = scoreCasamento(
        const AlvoCasamento(descricao: 'MDF LOURO FREIJO 18 MM', categoria: CategoriaMaterial.chapa),
        louro18,
      );
      expect(s, greaterThanOrEqualTo(0.85));
    });

    test('espessura diferente não casa', () {
      expect(
        scoreCasamento(const AlvoCasamento(descricao: 'MDF Louro Freijó 15mm'), louro18),
        0,
      );
      expect(
        scoreCasamento(
          const AlvoCasamento(descricao: 'MDF Louro Freijó', espessuraMm: 15),
          louro18,
        ),
        0,
      );
    });

    test('medida de ferragem tem de bater', () {
      final c450 = _mat('c450', 'Corrediça telescópica 450mm', cat: CategoriaMaterial.ferragem);
      expect(scoreCasamento(const AlvoCasamento(descricao: 'Corrediça telescópica 350mm'), c450), 0);
      expect(
        scoreCasamento(const AlvoCasamento(descricao: 'CORREDICA TELESC 450MM'), c450),
        greaterThanOrEqualTo(0.85),
      );
    });

    test('cor diferente fica longe', () {
      final branco = _mat('b', 'MDF Branco TX 18mm', esp: 18);
      expect(scoreCasamento(const AlvoCasamento(descricao: 'MDF Louro Freijó 18mm'), branco), lessThan(0.6));
    });

    test('abreviação cai na faixa da IA', () {
      final dob = _mat('d', 'Dobradiça 35mm c/ amortecedor', cat: CategoriaMaterial.ferragem);
      final s = scoreCasamento(const AlvoCasamento(descricao: 'DOB CALCO 35 C/AMORT RETA'), dob);
      expect(s, inInclusiveRange(0.6, 0.85));
    });

    test('referência e apelido exatos', () {
      final m = _mat('x', 'MDF Branco TX 18mm', ref: '1050-18-BT').copyWith(apelidos: ['mdf bco tx 18mm']);
      expect(porReferencia('1050 18 BT', [m]), isNotNull);
      expect(porApelido('MDF BCO TX 18MM', [m]), isNotNull);
    });
  });

  group('fluxo da lista', () {
    late FakeFirebaseFirestore db;
    late EstoqueService sistema;
    late _IAFake ia;

    Future<void> semear(List<MaterialEstoque> ms) async {
      for (final m in ms) {
        await db.collection('materiais').doc(m.id).set(m.toMap());
      }
    }

    Future<String> novaLista(String id, String projeto, List<ItemListaCorte> itens, DateTime quando) async {
      final l = ListaCorte(
        id: id,
        arquivoNome: '$id.pdf',
        arquivoHash: id,
        software: SoftwareLista.dinabox,
        projetoNome: projeto,
        status: StatusLista.lida,
        itens: itens,
      );
      await db.collection('listas_corte').doc(id).set({...l.toMap(), 'criadoEm': quando});
      await CasamentoService(db: db, ia: ia, estoque: sistema).processarLista(id);
      return id;
    }

    Future<ListaCorte> lista(String id) async =>
        ListaCorte.fromFirestore(await db.collection('listas_corte').doc(id).get());
    Future<MaterialEstoque> material(String id) async =>
        MaterialEstoque.fromFirestore(await db.collection('materiais').doc(id).get());

    setUp(() async {
      db = FakeFirebaseFirestore();
      sistema = EstoqueService.sistema(db: db);
      ia = _IAFake();
      EstoqueService.ouvintes.clear();
      await db.collection('fornecedores').doc('f1').set({'nome': 'Madeireira Central', 'whatsapp': '5518997124410'});
      await semear([
        _mat('branco', 'MDF Branco TX 18mm', esp: 18, fisico: 14, ref: '1050-18-BT', fornecedorId: 'f1'),
        _mat('louro', 'MDF Louro Freijó 18mm', esp: 18, fisico: 4, fornecedorId: 'f1', larg: 2750, alt: 1850),
        _mat('fita', 'Fita de borda branca 22mm', cat: CategoriaMaterial.fita, un: UnidadeEstoque.m, fisico: 260),
        _mat('dob', 'Dobradiça 35mm c/ amortecedor', cat: CategoriaMaterial.ferragem, un: UnidadeEstoque.un, fisico: 76),
      ]);
    });

    test('casa, reserva, cria o que não existe e monta o pedido', () async {
      final id = await novaLista('A', 'Cozinha Rodrigues', [
        _item('MDF BRANCO 18 (cód)', 6, 'ch', ref: '1050-18-BT', cat: CategoriaMaterial.chapa),
        _item('MDF Louro Freijó 18mm', 11.4, 'm²', cat: CategoriaMaterial.chapa),
        _item('Fita de borda branca 22mm', 48, 'm', cat: CategoriaMaterial.fita),
        _item('DOB CALCO 35 C/AMORT RETA', 12, 'un', cat: CategoriaMaterial.ferragem),
        _item('Corrediça telescópica 450mm', 8, 'par', cat: CategoriaMaterial.ferragem),
      ], DateTime(2026, 10, 20, 8));

      final l = await lista(id);
      final porDesc = {for (final i in l.itens) i.descricaoOriginal: i};
      expect(porDesc['MDF BRANCO 18 (cód)']!.metodoCasamento, MetodoCasamento.ref);
      expect(porDesc['MDF Louro Freijó 18mm']!.quantidade, 3); // 11,4 m² → 3 chapas
      expect(porDesc['MDF Louro Freijó 18mm']!.situacao, SituacaoItem.ok);
      expect(porDesc['DOB CALCO 35 C/AMORT RETA']!.metodoCasamento, MetodoCasamento.ia);
      expect(ia.chamadas, 1, reason: 'uma chamada de IA por lista');

      final corr = porDesc['Corrediça telescópica 450mm']!;
      expect(corr.metodoCasamento, MetodoCasamento.criado);
      expect(corr.situacao, SituacaoItem.falta);
      expect(corr.qtdFaltante, 8);
      expect(l.status, StatusLista.aguardandoCompra);

      expect((await material('branco')).estoqueReservado, 6);
      expect((await material('louro')).estoqueReservado, 3);
      // Aprendeu o apelido da dobradiça.
      expect((await material('dob')).apelidos, contains('dob calco 35 c amort reta'));

      final semForn = PedidoCompra.fromFirestore(
        await db.collection('pedidos_compra').doc(PedidoService.idRascunho(null)).get(),
      );
      expect(semForn.itens.single.quantidade, 8);
      expect(semForn.itens.single.porLista, {'A': 8});

      final avisos = await db.collection('avisos').get();
      expect(avisos.docs.map((d) => d['texto']), contains('Cozinha Rodrigues lida: 4 de 5 itens em estoque, 1 no pedido.'));
    });

    test('IA com pouca certeza manda pra confirmar com sugestões', () async {
      ia = _IAFake(confianca: 0.5);
      final id = await novaLista('A', 'X', [
        _item('DOB CALCO 35 C/AMORT RETA', 12, 'un', cat: CategoriaMaterial.ferragem),
      ], DateTime(2026, 10, 20));
      final it = (await lista(id)).itens.single;
      expect(it.situacao, SituacaoItem.confirmar);
      expect(it.sugestoes.first.materialId, 'dob');
      expect((await material('dob')).estoqueReservado, 0);

      // Confirmar roda casamento → reserva só pra ele e aprende.
      await CasamentoService(db: db, ia: ia, estoque: sistema).confirmarItem(id, 0, 'dob');
      final depois = await lista(id);
      expect(depois.itens.single.situacao, SituacaoItem.ok);
      expect(depois.status, StatusLista.reservada);
      expect((await material('dob')).estoqueReservado, 12);
      expect((await material('dob')).apelidos, contains('dob calco 35 c amort reta'));
    });

    test('segunda lista não pega a reserva da primeira', () async {
      await novaLista('A', 'Cozinha', [_item('MDF Louro Freijó 18mm', 3, 'ch')], DateTime(2026, 10, 20, 8));
      await novaLista('B', 'Closet', [_item('MDF Louro Freijó 18mm', 3, 'ch')], DateTime(2026, 10, 20, 9));

      final a = (await lista('A')).itens.single;
      final b = (await lista('B')).itens.single;
      expect(a.qtdReservada, 3);
      expect(a.situacao, SituacaoItem.ok);
      expect(b.qtdReservada, 1);
      expect(b.situacao, SituacaoItem.parcial);
      expect((await material('louro')).estoqueReservado, 4);
      expect((await lista('B')).status, StatusLista.aguardandoCompra);
    });

    test('lista nova não passa na frente de quem já esperava', () async {
      await novaLista('A', 'Cozinha', [_item('MDF Louro Freijó 18mm', 6, 'ch')], DateTime(2026, 10, 20, 8));
      expect((await lista('A')).itens.single.qtdFaltante, 2);
      // Inventário achou 2 chapas (ajuste não realoca sozinho)...
      await sistema.ajustar(materialId: 'louro', novoFisico: 6);
      // ...e uma lista nova chega querendo 2: a antiga é atendida antes.
      await novaLista('B', 'Closet', [_item('MDF Louro Freijó 18mm', 2, 'ch')], DateTime(2026, 10, 20, 9));
      expect((await lista('A')).itens.single.situacao, SituacaoItem.ok);
      expect((await lista('B')).itens.single.qtdReservada, 0);
    });

    test('material que chega libera as listas que esperavam (realocação)', () async {
      await novaLista('A', 'Cozinha', [_item('MDF Louro Freijó 18mm', 3, 'ch')], DateTime(2026, 10, 20, 8));
      await novaLista('B', 'Closet', [_item('MDF Louro Freijó 18mm', 3, 'ch')], DateTime(2026, 10, 20, 9));
      final rascunho = db.collection('pedidos_compra').doc(PedidoService.idRascunho('f1'));
      expect(PedidoCompra.fromFirestore(await rascunho.get()).itens.single.quantidade, 2);

      await PedidoService(db: db, estoque: sistema).registrarRecebimento(
        materialId: 'louro',
        quantidade: 5,
        custoUnitario: 320,
        fornecedorId: 'f1',
        notaFiscalId: 'NF1',
      );

      final b = await lista('B');
      expect(b.itens.single.situacao, SituacaoItem.ok);
      expect(b.status, StatusLista.pronta);
      expect((await material('louro')).estoqueFisico, 9);
      expect((await material('louro')).estoqueReservado, 6);
      // A falta foi coberta: o rascunho não precisa mais comprar.
      expect((await rascunho.get()).exists, isFalse);
      final avisos = await db.collection('avisos').get();
      expect(avisos.docs.map((d) => d['texto']), contains('Closet está pronta para cortar.'));
    });

    test('cortada dá baixa consumindo a reserva', () async {
      await novaLista('A', 'Cozinha', [_item('MDF Branco TX 18mm', 6, 'ch')], DateTime(2026, 10, 20));
      final joao = EstoqueService(db: db, responsavel: const Responsavel('u1', 'João'));
      await ListaService(db: db, estoque: joao).marcarCortada('A');

      final m = await material('branco');
      expect(m.estoqueFisico, 8);
      expect(m.estoqueReservado, 0);
      final l = await lista('A');
      expect(l.status, StatusLista.cortada);
      expect(l.cortadaPor, 'João');
      final saida = await db.collection('movimentacoes').where('tipo', isEqualTo: 'saida').get();
      expect(saida.docs.single['origem'], 'projetoCortado');
      expect(saida.docs.single['responsavelNome'], 'João');
      expect(saida.docs.single['projetoNome'], 'Cozinha');
    });

    test('comprado por fora entra e sai na hora', () async {
      await novaLista('A', 'Cozinha', [_item('MDF Louro Freijó 18mm', 6, 'ch')], DateTime(2026, 10, 20));
      await ListaService(db: db, estoque: sistema).marcarCortada('A', compradoPorFora: true);
      final m = await material('louro');
      expect(m.estoqueFisico, 0);
      expect(m.estoqueReservado, 0);
    });

    test('cancelar libera e repassa pra quem esperava', () async {
      await novaLista('A', 'Cozinha', [_item('MDF Louro Freijó 18mm', 4, 'ch')], DateTime(2026, 10, 20, 8));
      await novaLista('B', 'Closet', [_item('MDF Louro Freijó 18mm', 2, 'ch')], DateTime(2026, 10, 20, 9));
      expect((await lista('B')).itens.single.qtdReservada, 0);

      await ListaService(db: db, estoque: sistema).cancelarLista('A');
      expect((await lista('A')).status, StatusLista.cancelada);
      expect((await lista('B')).itens.single.situacao, SituacaoItem.ok);
      expect((await material('louro')).estoqueReservado, 2);
    });

    test('abaixo do mínimo entra no pedido sem duplicar', () async {
      EstoqueService.ouvintes.add((m, _) => PedidoService(db: db, estoque: sistema).garantirMinimo(m));
      await semear([_mat('mdp', 'MDP Cinza Cristal 15mm', esp: 15, fisico: 6, minimo: 5, fornecedorId: 'f1')]);

      await sistema.perda(materialId: 'mdp', quantidade: 3, motivo: 'Chapa empenada');
      await sistema.perda(materialId: 'mdp', quantidade: 1, motivo: 'Molhou');

      final p = PedidoCompra.fromFirestore(
        await db.collection('pedidos_compra').doc(PedidoService.idRascunho('f1')).get(),
      );
      final item = p.itens.single;
      expect(item.origem, OrigemItemPedido.minimo);
      expect(item.qtdMinimo, 3); // disponível 2, mínimo 5
      expect(item.quantidade, 3);
      EstoqueService.ouvintes.clear();
    });

    test('mensagem do WhatsApp no formato combinado', () {
      const p = PedidoCompra(
        id: 'x',
        fornecedorId: 'f1',
        fornecedorNome: 'Madeireira Central',
        status: StatusPedido.rascunho,
        itens: [
          ItemPedido(materialId: 'l', nome: 'MDF Louro Freijó 18mm', refFornecedor: '1052-18-LF', quantidade: 3, unidade: UnidadeEstoque.ch, origem: OrigemItemPedido.lista),
          ItemPedido(materialId: 'c', nome: 'Corrediça telescópica 450mm', quantidade: 8, unidade: UnidadeEstoque.par, origem: OrigemItemPedido.lista),
        ],
      );
      expect(
        PedidoService.mensagem(p),
        'Olá, Madeireira Central! Pedido da Dellalio:\n\n'
        '• 3 ch — MDF Louro Freijó 18mm (ref. 1052-18-LF)\n'
        '• 8 par — Corrediça telescópica 450mm\n'
        '\nObrigado!',
      );
    });
  });
}
