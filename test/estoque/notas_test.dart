import 'dart:io';
import 'dart:typed_data';

import 'package:DELLALIO/estoque/importacao/canal_ia.dart';
import 'package:DELLALIO/estoque/models/models.dart';
import 'package:DELLALIO/estoque/notas/importador_notas.dart';
import 'package:DELLALIO/estoque/notas/nota_lida.dart';
import 'package:DELLALIO/estoque/services/casamento_service.dart';
import 'package:DELLALIO/estoque/services/estoque_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _IAFake extends CanalIA {
  int chamadas = 0;
  @override
  Future<List<Map<String, dynamic>>> desempatar(List<Map<String, dynamic>> itens) async {
    chamadas++;
    return [
      for (final i in itens)
        {'indice': i['indice'], 'materialId': (i['candidatos'] as List).first['materialId'], 'confianca': 0.92},
    ];
  }
}

void main() {
  final xml = File('test/fixtures/nfe_madeireira.xml').readAsStringSync();

  test('parse do XML da NF-e', () {
    final n = lerXmlNfe(xml);
    expect(n.chaveAcesso, '35261012345678000190550010000482131000482130');
    expect(n.idDocumento, n.chaveAcesso);
    expect(n.cnpjEmitente, '12345678000190');
    expect(n.nomeEmitente, 'Madeireira Central');
    expect(n.foneEmitente, '18997124410');
    expect(n.numero, '48213');
    expect(n.emitidaEm, isNotNull);
    expect(n.itens, hasLength(3));
    expect(n.itens.first.codigo, '1052-18-LF');
    expect(n.itens.first.quantidade, 5);
    expect(n.itens.first.valorUnitario, 320);
    expect(n.itens[1].ean, '7891234567895');
    expect(n.itens[2].unidade, 'CX');
    expect(pareceXmlNfe(xml), isTrue);
  });

  group('entrada pela nota', () {
    late FakeFirebaseFirestore db;
    late EstoqueService sistema;
    late _IAFake ia;
    late ImportadorNotas imp;

    Future<MaterialEstoque> material(String id) async =>
        MaterialEstoque.fromFirestore(await db.collection('materiais').doc(id).get());

    setUp(() async {
      db = FakeFirebaseFirestore();
      sistema = EstoqueService.sistema(db: db);
      ia = _IAFake();
      imp = ImportadorNotas(db: db, ia: ia, estoque: sistema);
      EstoqueService.ouvintes.clear();
      Future<void> mat(MaterialEstoque m) => db.collection('materiais').doc(m.id).set(m.toMap());
      await mat(const MaterialEstoque(id: 'louro', nome: 'MDF Louro Freijó 18mm', categoria: CategoriaMaterial.chapa, unidade: UnidadeEstoque.ch, espessuraMm: 18, custoMedio: 300));
      await mat(const MaterialEstoque(id: 'fita', nome: 'Fita de borda branca 22mm', categoria: CategoriaMaterial.fita, unidade: UnidadeEstoque.m, estoqueFisico: 100, custoMedio: 1.0));
      await mat(const MaterialEstoque(id: 'paraf', nome: 'Parafuso 4x40 Philips', categoria: CategoriaMaterial.insumo, unidade: UnidadeEstoque.un));

      // Lista esperando 3 chapas de Louro.
      await db.collection('listas_corte').doc('L1').set({
        ...const ListaCorte(
          id: 'L1',
          arquivoNome: 'cozinha.pdf',
          arquivoHash: 'L1',
          software: SoftwareLista.dinabox,
          projetoNome: 'Cozinha Rodrigues',
          status: StatusLista.lida,
          itens: [ItemListaCorte(descricaoOriginal: 'MDF Louro Freijó 18mm', quantidadeOriginal: 3, unidadeOriginal: 'ch')],
        ).toMap(),
        'criadoEm': DateTime(2026, 10, 18),
      });
      await CasamentoService(db: db, ia: ia, estoque: sistema).processarLista('L1');
    });

    test('dá entrada, atualiza custo, libera a lista e não duplica', () async {
      final bytes = Uint8List.fromList(xml.codeUnits);
      final id = await imp.importarBytes('nfe.xml', bytes);
      expect(id, '35261012345678000190550010000482131000482130');

      final louro = await material('louro');
      expect(louro.estoqueFisico, 5);
      expect(louro.custoMedio, 320); // físico era 0
      expect(louro.estoqueReservado, 3); // realocado pra lista
      expect(louro.refFornecedor, '1052-18-LF');

      final fita = await material('fita');
      expect(fita.estoqueFisico, 200);
      expect(fita.custoMedio, closeTo(1.05, 1e-9));

      final lista = ListaCorte.fromFirestore(await db.collection('listas_corte').doc('L1').get());
      expect(lista.status, StatusLista.pronta);

      final nota = NotaFiscal.fromFirestore(await db.collection('notas_fiscais').doc(id).get());
      expect(nota.status, StatusNota.parcial); // a caixa de parafuso ficou pra confirmar
      expect(nota.movimentacaoIds, hasLength(2));
      final parafuso = nota.itens[2];
      expect(parafuso.situacao, SituacaoItemNota.confirmar);
      expect(parafuso.pergunta, 'Quantos un vêm em 1 CX?');

      // Fornecedor criado pelo CNPJ, com os códigos aprendidos.
      final f = Fornecedor.fromFirestore((await db.collection('fornecedores').get()).docs.single);
      expect(f.cnpj, '12345678000190');
      expect(f.whatsapp, '5518997124410');
      expect(f.codigosProduto['1052-18-LF'], 'louro');

      final avisos = (await db.collection('avisos').get()).docs.map((d) => d['texto'] as String);
      expect(
        avisos,
        contains('NF 48213 de Madeireira Central: 2 itens lançados. 1 precisa de confirmação. '
            'Cozinha Rodrigues agora está pronta para cortar.'),
      );

      // O mesmo XML de novo: ignora em silêncio.
      expect(await imp.importarBytes('copia.xml', bytes), isNull);
      expect((await material('louro')).estoqueFisico, 5);
    });

    test('pergunta da caixa é respondida uma vez e fica guardada', () async {
      final id = (await imp.importarBytes('nfe.xml', Uint8List.fromList(xml.codeUnits)))!;
      await imp.responderEmbalagem(id, 2, 500);

      final p = await material('paraf');
      expect(p.estoqueFisico, 1000);
      expect(p.fatorEmbalagem['CX'], 500);
      expect(p.custoMedio, closeTo(38 / 500, 1e-9));
      final nota = NotaFiscal.fromFirestore(await db.collection('notas_fiscais').doc(id).get());
      expect(nota.status, StatusNota.lancada);
    });

    test('segunda nota do fornecedor casa pelo código, sem IA', () async {
      await imp.importarBytes('nfe.xml', Uint8List.fromList(xml.codeUnits));
      final antes = ia.chamadas;
      final outra = xml
          .replaceAll('35261012345678000190550010000482131000482130', '35261012345678000190550010000499991000499990')
          .replaceAll('<nNF>48213</nNF>', '<nNF>49999</nNF>')
          .replaceAll('MDF LOURO FREIJO 18MM 2750X1850 2F', 'CHAPA LF18 PROMO');
      await imp.importarBytes('nfe2.xml', Uint8List.fromList(outra.codeUnits));
      expect(ia.chamadas, antes, reason: 'código aprendido dispensa a IA');
      expect((await material('louro')).estoqueFisico, 10);
    });
  });
}
