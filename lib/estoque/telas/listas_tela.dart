import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/user_session.dart';
import '../importacao/automacao.dart';
import '../importacao/vigia_pasta.dart';
import '../models/models.dart';
import '../services/casamento_service.dart';
import '../services/consultas.dart';
import '../services/estoque_service.dart';
import '../services/lista_service.dart';
import '../ui/formatos.dart';
import '../ui/kit_estoque.dart';
import '../util/datas.dart';
import '../util/quantidade.dart';
import 'dialogos.dart';
import 'nav_cerebro.dart';
import 'visao_geral.dart' show pilulaLista;

enum _FiltroLista {
  ativas('Ativas'),
  aguardando('Aguardando compra'),
  prontas('Prontas'),
  cortadas('Cortadas'),
  canceladas('Canceladas'),
  todas('Todas');

  const _FiltroLista(this.rotulo);
  final String rotulo;

  bool aceita(ListaCorte l) => switch (this) {
    ativas => l.status.ativa,
    aguardando => l.status == StatusLista.aguardandoCompra,
    prontas => l.status == StatusLista.pronta || l.status == StatusLista.reservada,
    cortadas => l.status == StatusLista.cortada,
    canceladas => l.status == StatusLista.cancelada,
    todas => true,
  };
}

/// Seção "Listas de corte": a lista de listas, ou a conferência quando há
/// uma aberta.
class ListasTela extends StatelessWidget {
  const ListasTela({super.key});

  @override
  Widget build(BuildContext context) {
    final id = NavCerebro.of(context).listaId;
    return AnimatedSwitcher(
      duration: Duration(milliseconds: semAnimacao(context) ? 0 : 250),
      // O padrão centraliza; aqui a página ocupa tudo, do topo.
      layoutBuilder: (atual, anteriores) => Stack(
        fit: StackFit.expand,
        children: [...anteriores, ?atual],
      ),
      child: id == null
          ? const _ListaDeListas(key: ValueKey('listas'))
          : ConferenciaLista(key: ValueKey(id), listaId: id),
    );
  }
}

class _ListaDeListas extends StatefulWidget {
  const _ListaDeListas({super.key});
  @override
  State<_ListaDeListas> createState() => _ListaDeListasState();
}

class _ListaDeListasState extends State<_ListaDeListas> {
  _FiltroLista _filtro = _FiltroLista.ativas;
  bool _importando = false;

  Future<void> _importar() async {
    final r = await FilePicker.pickFiles(
      dialogTitle: 'Importar lista ou nota',
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'csv', 'xlsx', 'xls', 'xml'],
      allowMultiple: true,
    );
    if (r == null) return;
    setState(() => _importando = true);
    for (final f in r.files) {
      if (f.path == null) continue;
      final tipo = await Automacao.instancia.importarArquivo(File(f.path!));
      if (!mounted) return;
      avisar(context, switch (tipo) {
        TipoImportado.lista => '${f.name}: lista importada.',
        TipoImportado.nota => '${f.name}: nota lançada.',
        TipoImportado.repetido => '${f.name} já tinha sido importado.',
        TipoImportado.falhou => 'Não consegui ler ${f.name}.',
      });
    }
    if (mounted) setState(() => _importando = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ListaCorte>>(
      stream: Consultas.instancia.listasRecentes(limite: 200),
      builder: (context, snap) {
        if (snap.hasError) return ErroConsulta(snap.error!);
        final todas = snap.data ?? const <ListaCorte>[];
        final listas = todas.where(_filtro.aceita).toList();
        final confirmar = todas.where((l) => l.status.ativa).fold<int>(0, (s, l) => s + l.resumo.confirmar);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(34, 26, 34, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Cascata(
                indice: 0,
                child: CabecalhoPagina(
                  titulo: 'Listas de corte',
                  subtitulo: '${todas.where((l) => l.status.ativa).length} ativas'
                      '${confirmar > 0 ? ' · $confirmar ${confirmar == 1 ? 'item' : 'itens'} para confirmar' : ''}',
                ),
              ),
              const SizedBox(height: 20),
              Cascata(indice: 1, child: _AreaSoltar(importando: _importando, onImportar: _importar)),
              const SizedBox(height: 18),
              Cascata(
                indice: 2,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in _FiltroLista.values)
                      ChipFiltro(rotulo: f.rotulo, ativo: _filtro == f, onTap: () => setState(() => _filtro = f)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (!snap.hasData)
                const Carregando()
              else if (listas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Text('Nenhuma lista nesse filtro.', style: TextStyle(color: panelSlate)),
                )
              else
                LayoutBuilder(
                  builder: (context, cons) {
                    final colunas = cons.maxWidth > 1100 ? 3 : (cons.maxWidth > 700 ? 2 : 1);
                    final largura = (cons.maxWidth - 16 * (colunas - 1)) / colunas;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final (i, l) in listas.indexed)
                          SizedBox(
                            width: largura,
                            child: Cascata(key: ValueKey(l.id), indice: i, child: _CardLista(l)),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AreaSoltar extends StatelessWidget {
  final bool importando;
  final VoidCallback onImportar;
  const _AreaSoltar({required this.importando, required this.onImportar});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstadoVigia>(
      valueListenable: Automacao.instancia.vigiaListas.estado,
      builder: (context, v, _) => BordaTracejada(
        cor: estoqueOuro.withValues(alpha: 0.5),
        raio: 14,
        fundo: inkSurface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: hairlineNavy),
                ),
                child: Icon(Icons.file_download_outlined, color: estoqueOuro),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Solte aqui a lista do DinaBox', style: TextStyle(color: panelIvory, fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(
                      'PDF, CSV ou XLSX — ou salve em ${v.caminho ?? r'Documentos\Dellalio\Listas'}. Notas fiscais também podem ser soltas aqui.',
                      style: TextStyle(color: panelSlate, fontSize: 13),
                    ),
                  ],
                ),
              ),
              PilulaStatus(
                rotulo: v.ativo ? 'vigiando' : (v.erro != null ? 'pasta com erro' : 'parado'),
                cor: v.ativo ? estoqueOk : estoqueFalta,
              ),
              const SizedBox(width: 12),
              BotaoEstoque(rotulo: 'Importar arquivo', icone: Icons.upload_file, carregando: importando, onPressed: onImportar),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardLista extends StatelessWidget {
  final ListaCorte l;
  const _CardLista(this.l);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: inkSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => NavCerebro.ler(context).abrirLista(l.id),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: l.status == StatusLista.pronta ? estoqueOk.withValues(alpha: 0.5) : hairlineNavy),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(l.titulo, style: fraunces(20))),
                  const SizedBox(width: 8),
                  pilulaLista(l),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtituloLista(l), style: TextStyle(color: panelSlateDim, fontSize: 12.5)),
              const SizedBox(height: 14),
              BarraSituacao(
                resumo: l.resumo,
                neutra: l.status == StatusLista.cortada || l.status == StatusLista.cancelada,
              ),
              const SizedBox(height: 10),
              Text(
                '${l.resumo.ok} reservados · ${l.resumo.parcial + l.resumo.falta} a comprar'
                '${l.resumo.confirmar > 0 ? ' · ${l.resumo.confirmar} a confirmar' : ''}',
                style: TextStyle(color: panelSlate, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================ conferência

class ConferenciaLista extends StatelessWidget {
  final String listaId;
  const ConferenciaLista({super.key, required this.listaId});

  @override
  Widget build(BuildContext context) {
    return Vivos(
      streams: [
        Consultas.instancia.lista(listaId),
        Consultas.instancia.materiais(incluirInativos: true),
        Consultas.instancia.listasAtivas(),
      ],
      builder: (context, v) {
        final l = v[0] as ListaCorte?;
        if (l == null) {
          return Center(child: Text('Lista não encontrada.', style: TextStyle(color: panelSlate)));
        }
        final materiais = {for (final m in v[1] as List<MaterialEstoque>) m.id: m};
        final outras = (v[2] as List<ListaCorte>).where((x) => x.id != l.id).toList();
        return _Conferencia(lista: l, materiais: materiais, outras: outras);
      },
    );
  }
}

class _Conferencia extends StatelessWidget {
  final ListaCorte lista;
  final Map<String, MaterialEstoque> materiais;
  final List<ListaCorte> outras;
  const _Conferencia({required this.lista, required this.materiais, required this.outras});

  bool get _cortavel => lista.status == StatusLista.pronta || lista.status == StatusLista.reservada;
  bool get _encerrada => lista.status == StatusLista.cortada || lista.status == StatusLista.cancelada;

  /// Abre o arquivo original no programa padrão do Windows (PDF, planilha).
  /// Visualizador dentro do app foi descartado: travava o sistema.
  Future<void> _verArquivo(BuildContext context) async {
    final caminho = lista.arquivoCaminho;
    final local = caminho != null && File(caminho).existsSync();
    final uri = local ? Uri.file(caminho) : (lista.arquivoUrl == null ? null : Uri.parse(lista.arquivoUrl!));
    if (uri == null || !await launchUrl(uri)) {
      if (context.mounted) avisar(context, 'O arquivo original não está nesta máquina.', erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = NavCerebro.ler(context);
    final r = lista.resumo;
    final confirmar = [
      for (final (i, it) in lista.itens.indexed)
        if (it.situacao == SituacaoItem.confirmar && !_encerrada) (i, it),
    ];
    final outrosItens = [
      for (final (i, it) in lista.itens.indexed)
        if (!(it.situacao == SituacaoItem.confirmar && !_encerrada)) (i, it),
    ];

    Widget contador(String rotulo, int n, Color cor) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: inkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hairlineNavy),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo, style: TextStyle(color: panelSlate, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            NumeroAnimado(valor: n.toDouble(), formatar: (v) => v.round().toString(), estilo: fraunces(34, cor: cor)),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(34, 26, 34, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Cascata(
            indice: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Voltar às listas',
                  onPressed: nav.fecharLista,
                  icon: Icon(Icons.arrow_back, color: panelSlate),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${lista.arquivoNome} · ${lista.software.rotulo} · lida ${lista.criadoEm == null ? 'agora' : 'às ${fmtHora(lista.criadoEm)}'}'
                        '${lista.criadoEm != null && fmtQuando(lista.criadoEm, comHora: false) != 'hoje' ? ' de ${fmtQuando(lista.criadoEm, comHora: false)}' : ''}',
                        style: TextStyle(color: panelSlateDim, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(lista.titulo, style: fraunces(36)),
                    ],
                  ),
                ),
                BotaoEstoque(rotulo: 'Ver arquivo', icone: Icons.description_outlined, variante: VarianteBotao.fantasma, onPressed: () => _verArquivo(context)),
                const SizedBox(width: 10),
                BotaoEstoque(
                  rotulo: 'Ver pedido',
                  icone: Icons.shopping_cart_outlined,
                  onPressed: () => nav.ir(SecaoCerebro.pedidos),
                ),
                const SizedBox(width: 10),
                if (!_encerrada)
                  BotaoEstoque(
                    rotulo: 'Marcar como cortado',
                    icone: Icons.content_cut,
                    variante: VarianteBotao.principal,
                    esmaecido: !_cortavel,
                    onPressed: () => cortarLista(context, lista),
                  ),
                if (!_encerrada)
                  PopupMenuButton<String>(
                    tooltip: 'Mais',
                    color: inkSurface,
                    icon: Icon(Icons.more_vert, color: panelSlate),
                    onSelected: (v) async {
                      if (v != 'cancelar') return;
                      final ok = await perguntar(
                        context,
                        titulo: 'Cancelar lista',
                        texto: 'As reservas da ${lista.titulo} voltam para o estoque e o que estava no pedido só por causa dela sai do rascunho.',
                        sim: 'Cancelar lista',
                        nao: 'Voltar',
                        perigo: true,
                      );
                      if (ok == true) await ListaService().cancelarLista(lista.id);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'cancelar', child: Text('Cancelar lista', style: TextStyle(color: estoqueFalta))),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Cascata(
            indice: 1,
            child: Row(
              children: [
                contador('Tem tudo', r.ok, estoqueOk),
                const SizedBox(width: 12),
                contador('Parcial', r.parcial, estoqueAlerta),
                const SizedBox(width: 12),
                contador('Falta', r.falta, estoqueFalta),
                const SizedBox(width: 12),
                contador('Confirmar', r.confirmar, estoqueOuro),
              ],
            ),
          ),
          for (final (k, (i, it)) in confirmar.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Cascata(key: ValueKey('c$i'), indice: 2 + k, child: _Confirmar(lista: lista, indice: i, item: it)),
            ),
          const SizedBox(height: 18),
          if (lista.itens.isEmpty)
            PainelEstoque(
              child: Text(
                'Não consegui ler os itens deste arquivo. O texto extraído ficou salvo pra ajustar o leitor; abra o arquivo pra conferir.',
                style: TextStyle(color: panelSlate),
              ),
            )
          else
            Cascata(indice: 3, child: _Tabela(lista: lista, itens: outrosItens, materiais: materiais)),
          ..._rodape(),
        ],
      ),
    );
  }

  /// "Disponível já desconta 4 chapas de MDF Branco reservadas para o
  /// Closet Almeida."
  List<Widget> _rodape() {
    final frases = <String>[];
    final ids = {for (final i in lista.itens) ?i.materialId};
    for (final id in ids) {
      final m = materiais[id];
      if (m == null) continue;
      for (final o in outras) {
        final q = o.itens.where((i) => i.materialId == id).fold<double>(0, (s, i) => s + i.qtdReservada);
        if (q > 0) {
          final unidade = q == 1 ? m.unidade.singular : m.unidade.plural;
          frases.add('${fmtNumero(q)} $unidade de ${m.nome} reservadas para ${o.titulo}');
        }
      }
    }
    if (frases.isEmpty || _encerrada) return const [];
    return [
      const SizedBox(height: 14),
      Text('Disponível já desconta ${frases.take(3).join('; ')}.', style: TextStyle(color: panelSlateDim, fontSize: 12.5)),
    ];
  }
}

/// "Na lista: "DOB CALCO 35..." · É Dobradiça 35mm c/ amortecedor? [Sim] [Escolher outro]"
class _Confirmar extends StatefulWidget {
  final ListaCorte lista;
  final int indice;
  final ItemListaCorte item;
  const _Confirmar({required this.lista, required this.indice, required this.item});
  @override
  State<_Confirmar> createState() => _ConfirmarState();
}

class _ConfirmarState extends State<_Confirmar> {
  bool _ocupado = false;

  Future<void> _com(Future<void> Function() f) async {
    setState(() => _ocupado = true);
    try {
      await f();
    } catch (e) {
      if (mounted) avisar(context, 'Não deu: $e', erro: true);
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final sugestao = it.sugestoes.firstOrNull;
    // Criados só no clique: nada de Firestore no build.
    CasamentoService casamento() => CasamentoService();
    EstoqueService estoque() => EstoqueService();
    final escuro = UserSession.isDarkMode();
    final qtd = '${fmtNumero(it.quantidadeOriginal)} ${it.unidadeOriginal}';
    return BordaTracejada(
      cor: estoqueOuro.withValues(alpha: 0.6),
      fundo: dellalioGold.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            AnelPulsante(
              cor: dellalioGold,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: (escuro ? dellalioGold : petroleoColor).withValues(alpha: 0.12),
                ),
                child: Icon(Icons.warning_amber_rounded, size: 20, color: escuro ? dellalioGold : petroleoColor),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Na lista: "${it.descricaoOriginal}"', style: TextStyle(color: panelSlateDim, fontSize: 12.5)),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(color: panelIvory, fontSize: 16),
                      children: sugestao == null
                          ? [const TextSpan(text: 'Qual material é este?'), TextSpan(text: ' · $qtd', style: TextStyle(color: panelSlateDim, fontSize: 12.5))]
                          : [
                              const TextSpan(text: 'É '),
                              TextSpan(text: sugestao.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const TextSpan(text: '?'),
                              TextSpan(
                                text: ' · $qtd · ${(sugestao.score * 100).round()}% parecido',
                                style: TextStyle(color: panelSlateDim, fontSize: 12.5),
                              ),
                            ],
                    ),
                  ),
                  if (it.observacao != null)
                    Text(it.observacao!, style: TextStyle(color: panelSlateDim, fontSize: 12.5)),
                ],
              ),
            ),
            if (sugestao != null) ...[
              BotaoEstoque(
                rotulo: 'Sim',
                icone: Icons.check,
                variante: VarianteBotao.principal,
                pequeno: true,
                carregando: _ocupado,
                onPressed: () => _com(() => casamento().confirmarItem(widget.lista.id, widget.indice, sugestao.materialId, estoque: estoque())),
              ),
              const SizedBox(width: 8),
            ],
            BotaoEstoque(
              rotulo: sugestao == null ? 'Escolher material' : 'Escolher outro',
              pequeno: true,
              onPressed: _ocupado
                  ? null
                  : () async {
                      final id = await escolherMaterial(context, textoOriginal: it.descricaoOriginal, sugestoes: it.sugestoes);
                      if (id == null) return;
                      if (id == criarNovo) {
                        await _com(() => casamento().confirmarComMaterialNovo(widget.lista.id, widget.indice, estoque: estoque()));
                      } else {
                        await _com(() => casamento().confirmarItem(widget.lista.id, widget.indice, id, estoque: estoque()));
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _Tabela extends StatelessWidget {
  final ListaCorte lista;
  final List<(int, ItemListaCorte)> itens;
  final Map<String, MaterialEstoque> materiais;
  const _Tabela({required this.lista, required this.itens, required this.materiais});

  static const _flex = [22, 8, 9, 11];

  @override
  Widget build(BuildContext context) {
    Widget cab(String t) => RotuloCaixaAlta(t, cor: panelSlateDim);
    return Container(
      decoration: BoxDecoration(
        color: inkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hairlineNavy),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(flex: _flex[0], child: cab('Material')),
                Expanded(flex: _flex[1], child: cab('Precisa')),
                Expanded(flex: _flex[2], child: cab('Disponível')),
                Expanded(flex: _flex[3], child: cab('Situação')),
              ],
            ),
          ),
          for (final (k, (_, it)) in itens.indexed)
            Cascata(indice: k, child: _linha(it)),
        ],
      ),
    );
  }

  Widget _linha(ItemListaCorte it) {
    final m = it.materialId == null ? null : materiais[it.materialId];
    final nome = it.materialNome ?? it.descricaoOriginal;
    final sub = it.metodoCasamento == MetodoCasamento.criado
        ? 'material criado automaticamente'
        : it.observacao ?? (it.materialNome != null && it.materialNome != it.descricaoOriginal ? 'na lista: ${it.descricaoOriginal}' : null);
    final u = it.unidade ?? m?.unidade;
    // Disponível pra esta lista = disponível do material + o que ela já reservou.
    final disponivel = m == null ? null : m.disponivel + it.qtdReservada;
    final encerrada = lista.status == StatusLista.cortada || lista.status == StatusLista.cancelada;
    final (rotulo, cor) = encerrada
        ? (lista.status.rotulo, estoqueNeutro)
        : switch (it.situacao) {
            SituacaoItem.ok => ('Reservado', estoqueOk),
            SituacaoItem.parcial => ('Comprar ${fmtNumero(it.qtdFaltante)} · no pedido', estoqueAlerta),
            SituacaoItem.falta => ('Comprar ${fmtNumero(it.qtdFaltante)} · no pedido', estoqueFalta),
            SituacaoItem.confirmar => ('Confirmar', estoqueOuro),
          };
    return PiscaAoMudar(
      chave: it.situacao,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: hairlineNavy))),
        child: Row(
          children: [
            Expanded(
              flex: _flex[0],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: nome, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: panelIvory)),
                    if (it.metodoCasamento == MetodoCasamento.criado || (m?.criadoAutomaticamente ?? false))
                      const WidgetSpan(alignment: PlaceholderAlignment.middle, child: SeloNovo()),
                  ])),
                  if (sub != null)
                    Text(
                      sub,
                      style: TextStyle(color: it.conferirConversao ? estoqueAlerta : panelSlateDim, fontSize: 12.5),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: _flex[1],
              child: Text(
                u == null ? '${fmtNumero(it.quantidadeOriginal)} ${it.unidadeOriginal}' : fmtQtd(it.quantidade, u),
                style: TextStyle(color: panelIvory, fontFeatures: numerosTabulares),
              ),
            ),
            Expanded(
              flex: _flex[2],
              child: Text(
                disponivel == null || u == null ? '—' : (disponivel <= 0 ? '0' : fmtQtd(disponivel, u)),
                style: TextStyle(color: panelIvory, fontFeatures: numerosTabulares),
              ),
            ),
            Expanded(
              flex: _flex[3],
              child: Align(alignment: Alignment.centerLeft, child: PilulaStatus(rotulo: rotulo, cor: cor)),
            ),
          ],
        ),
      ),
    );
  }
}
