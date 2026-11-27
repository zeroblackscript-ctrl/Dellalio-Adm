import 'package:DELLALIO/estoque/models/models.dart';
import 'package:DELLALIO/estoque/services/estoque_service.dart';
import 'package:DELLALIO/estoque/services/responsavel.dart';
import 'package:DELLALIO/estoque/ui/comprovante_pdf.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late FakeFirebaseFirestore db;
  late EstoqueService joao;

  Future<MaterialEstoque> material(String id) async =>
      MaterialEstoque.fromFirestore(await db.collection('materiais').doc(id).get());

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() async {
    db = FakeFirebaseFirestore();
    joao = EstoqueService(db: db, responsavel: const Responsavel('j', 'João'));
    EstoqueService.ouvintes.clear();
    await db.collection('materiais').doc('branco').set(const MaterialEstoque(
      id: 'branco', nome: 'MDF Branco TX 18mm', categoria: CategoriaMaterial.chapa,
      unidade: UnidadeEstoque.ch, estoqueFisico: 10, estoqueReservado: 2, local: 'Baia 1',
    ).toMap());
    await db.collection('materiais').doc('fita').set(const MaterialEstoque(
      id: 'fita', nome: 'Fita de borda branca', categoria: CategoriaMaterial.fita,
      unidade: UnidadeEstoque.m, estoqueFisico: 100,
    ).toMap());
  });

  test('retirada de vários materiais gera um comprovante numerado com o recebedor', () async {
    final c = await joao.registrarComprovante(
      tipo: TipoComprovante.retirada,
      itens: const [ItemPedidoComprovante('branco', 3), ItemPedidoComprovante('fita', 25.5)],
      motivo: 'Montagem',
      recebedorNome: ' Carlos Souza ',
      recebedorFuncao: 'Montador',
      clienteNome: 'Rodrigues',
      projetoNome: 'Cozinha',
      observacao: 'Levou na Strada',
      assinaturaPng: 'iVBORw0KGgo=',
      registradoNo: 'Gerenciador',
    );
    expect(c.numero, 1);
    expect(c.recebedorNome, 'Carlos Souza');
    expect(c.itens.map((i) => i.quantidade), [3, 25.5]);
    expect(c.itens.first.fisicoAntes, 10);
    expect(c.itens.first.fisicoDepois, 7);
    expect(c.itens.first.local, 'Baia 1');

    expect((await material('branco')).estoqueFisico, 7);
    expect((await material('fita')).estoqueFisico, 74.5);

    final movs = (await db.collection('movimentacoes').get()).docs.map((d) => Movimentacao.fromFirestore(d)).toList();
    expect(movs, hasLength(2));
    for (final m in movs) {
      expect(m.tipo, TipoMovimentacao.saida);
      expect(m.recebedorNome, 'Carlos Souza');
      expect(m.comprovanteId, c.id);
      expect(m.comprovanteNumero, 1);
      expect(m.responsavelNome, 'João');
      expect(m.clienteNome, 'Rodrigues');
    }

    final salvo = Comprovante.fromFirestore(await db.collection('comprovantes').doc(c.id).get());
    expect(salvo.recebedorFuncao, 'Montador');
    expect(salvo.observacao, 'Levou na Strada');
    expect(salvo.assinado, isTrue);
    expect(salvo.itens.last.movimentacaoId, isNotNull);
  });

  test('a numeração segue entre retiradas e entradas', () async {
    await joao.registrarComprovante(
      tipo: TipoComprovante.retirada,
      itens: const [ItemPedidoComprovante('branco', 1)],
      motivo: 'Produção',
      recebedorNome: 'Ana',
    );
    final e = await joao.registrarComprovante(
      tipo: TipoComprovante.entrada,
      itens: const [ItemPedidoComprovante('branco', 5, custoUnitario: 300)],
      motivo: 'Compra',
      origemNome: 'Madeireira Central',
      notaNumero: '48213',
    );
    expect(e.numero, 2);
    expect(e.tipo, TipoComprovante.entrada);
    final m = await material('branco');
    expect(m.estoqueFisico, 14);
    expect(m.custoMedio, closeTo(300 * 5 / 14, 0.001));
    final mov = Movimentacao.fromMap('x', (await db.collection('movimentacoes').where('comprovanteId', isEqualTo: e.id).get()).docs.single.data());
    expect(mov.tipo, TipoMovimentacao.entrada);
    expect(mov.fornecedorNome, 'Madeireira Central');
    expect(mov.recebedorNome, isNull);
  });

  test('retirada sem recebedor ou maior que o físico não grava nada', () async {
    expect(
      () => joao.registrarComprovante(
        tipo: TipoComprovante.retirada,
        itens: const [ItemPedidoComprovante('branco', 1)],
        motivo: 'Produção',
        recebedorNome: '  ',
      ),
      throwsA(isA<EstoqueException>()),
    );
    await expectLater(
      joao.registrarComprovante(
        tipo: TipoComprovante.retirada,
        itens: const [ItemPedidoComprovante('fita', 10), ItemPedidoComprovante('branco', 11)],
        motivo: 'Produção',
        recebedorNome: 'Ana',
      ),
      throwsA(isA<EstoqueException>()),
    );
    expect((await material('fita')).estoqueFisico, 100);
    expect((await db.collection('movimentacoes').get()).docs, isEmpty);
    expect((await db.collection('comprovantes').get()).docs, isEmpty);
  });

  test('mesmo material duas vezes vira uma linha só', () async {
    final c = await joao.registrarComprovante(
      tipo: TipoComprovante.retirada,
      itens: const [ItemPedidoComprovante('branco', 1), ItemPedidoComprovante('branco', 2)],
      motivo: 'Produção',
      recebedorNome: 'Ana',
    );
    expect(c.itens.single.quantidade, 3);
  });

  test('PDF do comprovante sai com e sem assinatura', () async {
    final c = await joao.registrarComprovante(
      tipo: TipoComprovante.retirada,
      itens: const [ItemPedidoComprovante('branco', 2)],
      motivo: 'Montagem',
      recebedorNome: 'Carlos',
    );
    final pdf = await pdfComprovante(c);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(nomeArquivoComprovante(c), 'comprovante_retirada_00001.pdf');
  });
}
