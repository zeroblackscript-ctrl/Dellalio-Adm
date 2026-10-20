import 'dart:io';
import 'dart:typed_data';

import 'package:DELLALIO/estoque/importacao/arquivo_entrada.dart';
import 'package:DELLALIO/estoque/importacao/canal_ia.dart';
import 'package:DELLALIO/estoque/importacao/importador_listas.dart';
import 'package:DELLALIO/estoque/importacao/leitor.dart';
import 'package:DELLALIO/estoque/importacao/leitor_dinabox.dart';
import 'package:DELLALIO/estoque/importacao/leitor_generico.dart';
import 'package:DELLALIO/estoque/importacao/leitor_planilha.dart';
import 'package:DELLALIO/estoque/importacao/parser_linha.dart';
import 'package:DELLALIO/estoque/models/enums.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// IA que nunca responde: os testes não saem pra rede.
class _SemIA extends CanalIA {
  const _SemIA();
  @override
  Future<Object?> chamar(String funcao, Map<String, dynamic> dados) =>
      throw const IAIndisponivel('teste');
}

/// "PDF" de texto pronto, sem passar pelo extrator.
ArquivoEntrada _pdfTexto(String nome, String texto, {String meta = ''}) =>
    ArquivoEntrada(
      nome: nome,
      extensao: 'pdf',
      bytes: Uint8List.fromList(texto.codeUnits),
      texto: texto,
      metadados: meta,
    );

ItemLido _item(List<ItemLido> itens, String inicio) =>
    itens.firstWhere((i) => i.descricao.startsWith(inicio));

void main() {
  final dinabox = File('test/fixtures/dinabox_lista_compras.txt').readAsStringSync();

  group('LeitorDinabox', () {
    test('reconhece pelo marcador e lê todos os itens', () async {
      final e = _pdfTexto('lista_compras_cozinha_rodrigues.pdf', dinabox);
      expect(await LeitorDinabox().reconhece(e), greaterThanOrEqualTo(0.8));

      final lida = await LeitorDinabox().ler(e);
      expect(lida.software, SoftwareLista.dinabox);
      expect(lida.clienteNome, 'Rodrigues');
      expect(lida.projetoNome, 'Cozinha');
      expect(lida.itens, hasLength(9));
      expect(lida.confianca, greaterThanOrEqualTo(0.9));
    });

    test('chapas em chapa e em m², fita em metros, ferragens com ref', () {
      final itens = LeitorDinabox.lerTexto(dinabox).itens;

      final branco = _item(itens, 'MDF Branco TX 18mm');
      expect(branco.quantidade, 6);
      expect(branco.unidade, 'ch');
      expect(branco.categoria, CategoriaMaterial.chapa);
      expect(branco.espessuraMm, 18);
      expect(branco.larguraMm, 2750);
      expect(branco.alturaMm, 1850);

      final louro = _item(itens, 'MDF Louro Freijó 18mm');
      expect(louro.quantidade, 11.4);
      expect(louro.unidade, 'm²');

      expect(_item(itens, 'MDP Cinza').unidade, 'chapas');

      final fita = _item(itens, 'Fita de borda branca');
      expect(fita.quantidade, 48);
      expect(fita.unidade, 'm');
      expect(fita.categoria, CategoriaMaterial.fita);

      final dob = _item(itens, 'Dobradiça');
      expect(dob.refFornecedor, 'DB-35AM');
      expect(dob.descricao, 'Dobradiça 35mm c/ amortecedor');
      expect(dob.quantidade, 12);
      expect(dob.categoria, CategoriaMaterial.ferragem);

      final corr = _item(itens, 'Corrediça');
      expect(corr.refFornecedor, 'CT-450');
      expect(corr.quantidade, 8);
      expect(corr.unidade, 'par');

      expect(_item(itens, 'Parafuso 4x40').unidade, 'cx');
    });

    test('ignora total, custo e rodapé', () {
      final itens = LeitorDinabox.lerTexto(dinabox).itens;
      expect(itens.any((i) => i.descricao.toLowerCase().contains('total')), isFalse);
      expect(itens.any((i) => i.descricao.toLowerCase().contains('página')), isFalse);
    });

    test('sem marcador não passa de 0,35', () async {
      final semMarca = dinabox.replaceAll(RegExp('dinabox', caseSensitive: false), '');
      expect(await LeitorDinabox().reconhece(_pdfTexto('x.pdf', semMarca)), lessThanOrEqualTo(0.35));
    });

    test('marcador nos metadados do PDF também vale', () async {
      final semMarca = dinabox.replaceAll(RegExp('dinabox', caseSensitive: false), '');
      final e = _pdfTexto('x.pdf', semMarca, meta: 'Dinabox Report');
      expect(await LeitorDinabox().reconhece(e), greaterThanOrEqualTo(0.8));
    });
  });

  group('LeitorPlanilha', () {
    test('CSV com ; e cabeçalho abaixo de cliente/projeto', () async {
      final bytes = File('test/fixtures/lista_generica.csv').readAsBytesSync();
      final e = ArquivoEntrada.deBytes('closet_almeida.csv', bytes);
      final leitor = LeitorPlanilha(ia: const _SemIA());
      expect(await leitor.reconhece(e), 0.9);

      final lida = await leitor.ler(e);
      expect(lida.software, SoftwareLista.planilha);
      expect(lida.clienteNome, 'Almeida');
      expect(lida.projetoNome, 'Closet');
      expect(lida.itens, hasLength(4));
      final mdf = lida.itens.first;
      expect(mdf.descricao, 'MDF Branco TX 18mm');
      expect(mdf.refFornecedor, '1050-18-BT');
      expect(mdf.quantidade, 4);
      expect(mdf.custoUnitario, 312.40);
      expect(lida.itens[3].unidade, 'par');
    });

    test('XLSX lido direto do zip', () async {
      final bytes = File('test/fixtures/lista_generica.xlsx').readAsBytesSync();
      final e = ArquivoEntrada.deBytes('painel_tv_souza.xlsx', bytes);
      expect(e.tabela, isNotEmpty);
      final lida = await LeitorPlanilha(ia: const _SemIA()).ler(e);
      expect(lida.itens, hasLength(4));
      expect(lida.itens.first.refFornecedor, '1050-18-BT');
      expect(lida.itens[2].quantidade, 48);
      expect(lida.itens[2].unidade, 'm');
    });

    test('sem cabeçalho e sem IA deduz as colunas', () async {
      final e = ArquivoEntrada.deBytes(
        'x.csv',
        Uint8List.fromList('MDF Branco TX 18mm;3\nFita de borda branca;40\n'.codeUnits),
      );
      final lida = await LeitorPlanilha(ia: const _SemIA()).ler(e);
      expect(lida.itens.map((i) => i.quantidade), [3, 40]);
      expect(lida.confianca, lessThan(0.7));
    });
  });

  group('LeitorGenerico', () {
    test('confiança baixa mesmo lendo tudo', () async {
      const texto = 'Orçamento Madeireira\nMDF Branco 18mm 3 ch\nDobradiça reta 10 un\n';
      final lida = await LeitorGenerico().ler(_pdfTexto('orc.pdf', texto));
      expect(lida.itens, hasLength(2));
      expect(lida.confianca, lessThanOrEqualTo(0.6));
    });
  });

  group('itemDaLinha', () {
    test('quantidade colada na unidade', () {
      final i = itemDaLinha('MDF Louro Freijó 18mm 11,4m²')!;
      expect(i.quantidade, 11.4);
      expect(i.descricao, 'MDF Louro Freijó 18mm');
    });

    test('referência no meio do texto', () {
      final i = itemDaLinha('MDF Louro Freijó 18mm (ref. 1052-18-LF) 3 chapas')!;
      expect(i.refFornecedor, '1052-18-LF');
      expect(i.quantidade, 3);
    });

    test('medida no nome não vira quantidade', () {
      expect(itemDaLinha('Corrediça telescópica 450mm'), isNull);
    });
  });

  group('ImportadorListas', () {
    test('escolhe o DinaBox e não duplica o mesmo arquivo', () async {
      final db = FakeFirebaseFirestore();
      final processadas = <String>[];
      final imp = ImportadorListas(
        db: db,
        usarStorage: false,
        leitorIA: LeitorGenerico(),
        aposGravar: (id) async => processadas.add(id),
      );
      // Texto "PDF" sem extrator: importa pelos bytes de um TXT via ler().
      final lida = await imp.ler(_pdfTexto('lista.pdf', dinabox));
      expect(lida!.software, SoftwareLista.dinabox);

      final bytes = Uint8List.fromList(File('test/fixtures/lista_generica.csv').readAsBytesSync());
      final id1 = await imp.importarBytes('closet_almeida.csv', bytes);
      final id2 = await imp.importarBytes('copia.csv', bytes);
      expect(id1, isNotNull);
      expect(id2, isNull);
      expect(processadas, [id1]);

      final doc = await db.collection('listas_corte').doc(id1).get();
      expect(doc['status'], 'lida');
      expect(doc['arquivoHash'], id1);
      expect(doc['clienteNome'], 'Almeida');
      expect((doc['itens'] as List), hasLength(4));
      expect(doc['resumo']['confirmar'], 4);
    });

    test('nome do arquivo vira projeto quando o leitor não traz', () {
      expect(ImportadorListas.nomeDoArquivo('cozinha_silva.pdf'), 'Cozinha Silva');
      expect(ImportadorListas.nomeDoArquivo('lista_compras_cozinha_rodrigues.pdf'), 'Cozinha Rodrigues');
    });
  });
}
