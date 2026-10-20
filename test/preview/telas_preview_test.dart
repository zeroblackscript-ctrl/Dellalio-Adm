// Prévia visual das telas do Cérebro com dados falsos.
//
// Não é um teste de regressão: renderiza cada tela e grava PNGs pra comparar
// com as referências. Só roda com PREVIEW_DIR (pasta de saída) e
// PREVIEW_FONTES (pasta com Inter.ttf e Fraunces.ttf):
//   $env:PREVIEW_DIR='...'; $env:PREVIEW_FONTES='...'; flutter test test/preview
import 'dart:io';
import 'dart:ui' as ui;

import 'package:DELLALIO/core/theme.dart';
import 'package:DELLALIO/core/user_session.dart';
import 'package:DELLALIO/estoque/importacao/automacao.dart';
import 'package:DELLALIO/estoque/importacao/canal_ia.dart';
import 'package:DELLALIO/estoque/importacao/vigia_pasta.dart';
import 'package:DELLALIO/estoque/models/models.dart';
import 'package:DELLALIO/estoque/services/casamento_service.dart';
import 'package:DELLALIO/estoque/services/consultas.dart';
import 'package:DELLALIO/estoque/services/estoque_service.dart';
import 'package:DELLALIO/estoque/services/lista_service.dart';
import 'package:DELLALIO/estoque/services/pedido_service.dart';
import 'package:DELLALIO/estoque/services/responsavel.dart';
import 'package:DELLALIO/estoque/telas/cerebro_shell.dart';
import 'package:DELLALIO/estoque/telas/nav_cerebro.dart';
import 'package:DELLALIO/estoque/ui/kit_estoque.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _saida = Platform.environment['PREVIEW_DIR'];
final _fontes = Platform.environment['PREVIEW_FONTES'];

/// Desempate de mentira: aceita a dobradiça com pouca certeza (vira
/// "confirmar") e o resto com 0,9.
class _IA extends CanalIA {
  @override
  Future<List<Map<String, dynamic>>> desempatar(List<Map<String, dynamic>> itens) async => [
    for (final i in itens)
      {
        'indice': i['indice'],
        'materialId': (i['candidatos'] as List).first['materialId'],
        'confianca': (i['descricao'] as String).startsWith('DOB') ? 0.6 : 0.9,
      },
  ];
}

Future<void> _semear(FakeFirebaseFirestore db) async {
  final joao = EstoqueService(db: db, responsavel: const Responsavel('j', 'João'));
  final ana = EstoqueService(db: db, responsavel: const Responsavel('a', 'Ana'));
  final sistema = EstoqueService.sistema(db: db);
  EstoqueService.ouvintes
    ..clear()
    ..add((m, _) => PedidoService(db: db, estoque: sistema).garantirMinimo(m));

  await db.collection('fornecedores').doc('f1').set({'nome': 'Madeireira Central', 'whatsapp': '5518997124410', 'descricao': 'chapas e fitas'});
  await db.collection('fornecedores').doc('f2').set({'nome': 'Ferragens Paulista', 'whatsapp': '5518988201173', 'descricao': 'ferragens'});

  Future<void> mat(String id, String nome, CategoriaMaterial c, UnidadeEstoque u, double fisico, double custo,
      {String? ref, String? local, String? f, double minimo = 0, double? esp}) async {
    await db.collection('materiais').doc(id).set(MaterialEstoque(
      id: id, nome: nome, categoria: c, unidade: u, refFornecedor: ref, local: local,
      fornecedorId: f, estoqueMinimo: minimo, espessuraMm: esp,
      larguraMm: c == CategoriaMaterial.chapa ? 2750 : null, alturaMm: c == CategoriaMaterial.chapa ? 1850 : null,
    ).toMap());
    if (fisico > 0) await joao.entrada(materialId: id, quantidade: fisico, custoUnitario: custo, fornecedorNome: f == 'f1' ? 'Madeireira Central' : null);
  }

  await mat('branco', 'MDF Branco TX 18mm', CategoriaMaterial.chapa, UnidadeEstoque.ch, 18, 289.9, ref: '1050-18-BT', local: 'Baia 1', f: 'f1', minimo: 4, esp: 18);
  await mat('louro', 'MDF Louro Freijó 18mm', CategoriaMaterial.chapa, UnidadeEstoque.ch, 4, 312.4, ref: '1052-18-LF', local: 'Baia 3', f: 'f1', minimo: 2, esp: 18);
  await mat('mdp', 'MDP Cinza Cristal 15mm', CategoriaMaterial.chapa, UnidadeEstoque.ch, 8, 198, local: 'Baia 2', f: 'f1', minimo: 6, esp: 15);
  await mat('fita', 'Fita de borda branca 22mm', CategoriaMaterial.fita, UnidadeEstoque.m, 260, 1.1, local: 'Prateleira F1', f: 'f1');
  await mat('fitaLouro', 'Fita de borda Louro Freijó 22mm', CategoriaMaterial.fita, UnidadeEstoque.m, 80, 1.6, local: 'Prateleira F1', f: 'f1', minimo: 100);
  await mat('dob', 'Dobradiça 35mm c/ amortecedor', CategoriaMaterial.ferragem, UnidadeEstoque.un, 76, 9.9, local: 'Gaveteiro G2', f: 'f2', minimo: 80);
  await mat('pux', 'Puxador perfil alumínio', CategoriaMaterial.acessorio, UnidadeEstoque.m, 18, 32, local: 'Prateleira P3');
  await mat('paraf', 'Parafuso 4x40 Philips', CategoriaMaterial.insumo, UnidadeEstoque.cx, 9, 38, local: 'Gaveteiro G5');
  await mat('cola', 'Cola PVA 1 kg', CategoriaMaterial.insumo, UnidadeEstoque.un, 1, 24, minimo: 3);

  Future<void> lista(String id, String projeto, String cliente, DateTime quando, List<ItemListaCorte> itens) async {
    await db.collection('listas_corte').doc(id).set({
      ...ListaCorte(
        id: id, arquivoNome: 'lista_compras_${projeto.toLowerCase().replaceAll(' ', '_')}_${cliente.toLowerCase()}.pdf',
        arquivoHash: id, software: SoftwareLista.dinabox, projetoNome: projeto, clienteNome: cliente,
        status: StatusLista.lida, itens: itens,
      ).toMap(),
      'criadoEm': quando,
    });
    await CasamentoService(db: db, ia: _IA(), estoque: sistema).processarLista(id);
  }

  ItemListaCorte it(String d, double q, String u, [CategoriaMaterial? c]) =>
      ItemListaCorte(descricaoOriginal: d, quantidadeOriginal: q, unidadeOriginal: u, categoria: c);
  final hoje = DateTime.now();
  final d = DateTime(hoje.year, hoje.month, hoje.day);

  await lista('pereira', 'Banheiro', 'Pereira', d.subtract(const Duration(days: 5)), [
    it('MDP Cinza Cristal 15mm', 2, 'ch'), it('Fita de borda branca 22mm', 20, 'm'),
  ]);
  await ListaService(db: db, estoque: joao).marcarCortada('pereira');
  await lista('almeida', 'Closet', 'Almeida', d.subtract(const Duration(days: 3)), [
    it('MDF Branco TX 18mm', 4, 'ch'), it('MDF Louro Freijó 18mm', 3, 'ch'), it('Fita de borda Louro Freijó 22mm', 60, 'm'),
    it('Corrediça telescópica 450mm', 6, 'par', CategoriaMaterial.ferragem),
  ]);
  await lista('souza', 'Painel TV', 'Souza', d.subtract(const Duration(hours: 20)), [
    it('MDF Branco TX 18mm', 3, 'ch'), it('MDP Cinza Cristal 15mm', 1, 'ch'), it('Fita de borda branca 22mm', 48, 'm'),
    it('Dobradiça 35mm c/ amortecedor', 8, 'un'), it('Puxador perfil alumínio', 4, 'm'), it('Parafuso 4x40 Philips', 1, 'cx'),
  ]);
  await lista('rodrigues', 'Cozinha', 'Rodrigues', d.add(const Duration(hours: 8, minutes: 12)), [
    it('MDF Branco TX 18mm', 6, 'ch'), it('MDF Louro Freijó 18mm', 11.4, 'm²'), it('Fita de borda branca 22mm', 48, 'm'),
    it('Fita de borda Louro Freijó 22mm', 16, 'm'), it('DOB CALCO 35 C/AMORT RETA', 12, 'un', CategoriaMaterial.ferragem),
    it('Corrediça telescópica 450mm', 8, 'par', CategoriaMaterial.ferragem), it('Puxador perfil alumínio', 6, 'm'),
    it('Parafuso 4x40 Philips', 1, 'cx'),
  ]);
  await ana.perda(materialId: 'mdp', quantidade: 1, motivo: 'Chapa empenada');
  await joao.saida(materialId: 'fita', quantidade: 12, motivo: 'Produção', projetoNome: 'Painel TV', clienteNome: 'Souza', origem: OrigemMovimentacao.projetoCortado);
}

Future<void> _fontesLocais() async {
  final raiz = Platform.environment['FLUTTER_ROOT'];
  final icones = '$raiz/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  for (final (familia, caminho) in [
    ('Inter', '$_fontes/Inter.ttf'),
    ('Fraunces', '$_fontes/Fraunces.ttf'),
    if (raiz != null && File(icones).existsSync()) ('MaterialIcons', icones),
  ]) {
    final bytes = File(caminho).readAsBytesSync();
    final loader = FontLoader(familia)..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

Future<void> _foto(WidgetTester tester, String nome, Widget tela, {bool escuro = true}) async {
  await tester.runAsync(() async {
    if (UserSession.isDarkMode() != escuro) await UserSession.toggleDarkMode();
  });
  ThemeNotifier.instance.setMode(escuro ? ThemeMode.dark : ThemeMode.light);
  final chave = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: chave,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        brightness: escuro ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: inkPageBg,
        useMaterial3: false,
      ),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: tela,
    ),
  ));
  // Deixa os streams do Firestore falso chegarem e as entradas terminarem.
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 250));
  }
  final boundary = chave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await boundary.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_saida/$nome.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('prévia das telas do Cérebro', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    usarGoogleFonts = false;
    Responsavel.fixoParaTeste = const Responsavel('m', 'Marcos Dellalio');
    UserSession.validateAndSetAdmin(UserSession.adminKey);

    final db = FakeFirebaseFirestore();
    await tester.runAsync(() async {
      await initializeDateFormatting('pt_BR');
      await _fontesLocais();
      await _semear(db);
    });
    Consultas.instancia = Consultas(db: db);
    Automacao.instancia.vigiaListas.estado.value = const EstadoVigia(caminho: r'C:\Users\Marcos\Documents\Dellalio\Listas', ativo: true);
    Automacao.instancia.fonteNotas.vigia.estado.value = const EstadoVigia(caminho: r'C:\Users\Marcos\Documents\Dellalio\Notas', ativo: true);

    Widget shell(SecaoCerebro s, {String? lista, String? material}) => CerebroShell(
      key: UniqueKey(),
      iniciarAutomacao: false,
      secaoInicial: s,
      listaInicial: lista,
      materialInicial: material,
    );

    await _foto(tester, 'c1-visao-geral', shell(SecaoCerebro.visaoGeral));
    await _foto(tester, 'c2-materiais-ficha', shell(SecaoCerebro.materiais, material: 'louro'));
    await _foto(tester, 'c3-conferencia', shell(SecaoCerebro.listas, lista: 'rodrigues'));
    await _foto(tester, 'c4-pedidos', shell(SecaoCerebro.pedidos));
    await _foto(tester, 'c5-visao-geral-claro', shell(SecaoCerebro.visaoGeral), escuro: false);
    await _foto(tester, 'c6-listas', shell(SecaoCerebro.listas));
    await _foto(tester, 'c7-movimentacoes', shell(SecaoCerebro.movimentacoes));
    await _foto(tester, 'c8-configuracoes', shell(SecaoCerebro.configuracoes));
    await _foto(tester, 'c9-conferencia-claro', shell(SecaoCerebro.listas, lista: 'rodrigues'), escuro: false);
    await tester.pumpWidget(const SizedBox());
  }, skip: _saida == null || _fontes == null);
}
