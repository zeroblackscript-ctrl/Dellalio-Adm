import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../models/models.dart';
import '../services/cadastro_service.dart';
import '../services/consultas.dart';
import '../ui/formatos.dart';
import '../ui/kit_estoque.dart';
import '../util/normalizar.dart';
import '../util/quantidade.dart';
import 'dialogos.dart';
import 'etiquetas.dart';
import 'nav_cerebro.dart';

enum _Filtro { todos, categoria, minimo, novos }

class MateriaisTela extends StatefulWidget {
  const MateriaisTela({super.key});
  @override
  State<MateriaisTela> createState() => _MateriaisTelaState();
}

class _MateriaisTelaState extends State<MateriaisTela> {
  late final TextEditingController _busca;
  String _q = '';
  _Filtro _filtro = _Filtro.todos;
  CategoriaMaterial? _categoria;
  bool _selecionando = false;
  final Set<String> _selecionados = {};

  @override
  void initState() {
    super.initState();
    final nav = NavCerebro.ler(context);
    final pre = nav.buscaMateriais;
    if (pre == '#minimo') {
      _filtro = _Filtro.minimo;
      _busca = TextEditingController();
    } else {
      _busca = TextEditingController(text: pre ?? '');
      _q = normalizar(pre ?? '');
    }
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  bool _passa(MaterialEstoque m) {
    if (_q.isNotEmpty) {
      final texto = normalizar([m.nome, ?m.refFornecedor, ?m.local, ...m.apelidos].join(' '));
      if (!_q.split(' ').every(texto.contains)) return false;
    }
    return switch (_filtro) {
      _Filtro.todos => true,
      _Filtro.categoria => m.categoria == _categoria,
      _Filtro.minimo => m.abaixoDoMinimo,
      _Filtro.novos => m.criadoAutomaticamente,
    };
  }

  @override
  Widget build(BuildContext context) {
    final nav = NavCerebro.of(context);
    return StreamBuilder<List<MaterialEstoque>>(
      stream: Consultas.instancia.materiais(),
      builder: (context, snap) {
        if (snap.hasError) return ErroConsulta(snap.error!);
        if (!snap.hasData) return const Carregando();
        final todos = snap.data!;
        final lista = todos.where(_passa).toList();
        final abaixo = todos.where((m) => m.abaixoDoMinimo).length;
        final aberto = todos.where((m) => m.id == nav.materialId).firstOrNull;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(34, 26, 24, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Cascata(
                      indice: 0,
                      child: CabecalhoPagina(
                        titulo: 'Materiais',
                        subtitulo: '${todos.length} ativos · $abaixo abaixo do mínimo',
                        acoes: [
                          BuscaEstoque(
                            dica: 'Buscar',
                            largura: 240,
                            controller: _busca,
                            onChanged: (v) => setState(() => _q = normalizar(v)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Cascata(
                      indice: 1,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _chips()),
                          const SizedBox(width: 12),
                          if (_selecionando) ...[
                            BotaoEstoque(
                              rotulo: 'Imprimir ${_selecionados.length}',
                              icone: Icons.qr_code_2,
                              variante: VarianteBotao.principal,
                              pequeno: true,
                              onPressed: _selecionados.isEmpty
                                  ? null
                                  : () => imprimirEtiquetas(todos.where((m) => _selecionados.contains(m.id)).toList()),
                            ),
                            const SizedBox(width: 8),
                          ],
                          BotaoEstoque(
                            rotulo: _selecionando ? 'Cancelar' : 'Etiquetas',
                            icone: _selecionando ? Icons.close : Icons.qr_code_2,
                            variante: VarianteBotao.fantasma,
                            pequeno: true,
                            onPressed: () => setState(() {
                              _selecionando = !_selecionando;
                              _selecionados.clear();
                            }),
                          ),
                          if (!_selecionando) ...[
                            const SizedBox(width: 8),
                            BotaoEstoque(
                              rotulo: 'Novo',
                              icone: Icons.add,
                              pequeno: true,
                              onPressed: () async {
                                final id = await editarMaterial(context);
                                if (id != null && context.mounted) NavCerebro.ler(context).abrirMaterial(id);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Cascata(indice: 2, child: _tabela(lista, nav.materialId)),
                  ],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: Duration(milliseconds: semAnimacao(context) ? 0 : 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: aberto == null
                  ? const SizedBox.shrink(key: ValueKey('fechada'))
                  : FichaMaterial(key: ValueKey(aberto.id), material: aberto),
            ),
          ],
        );
      },
    );
  }

  Widget _chips() {
    Widget chip(String r, bool ativo, VoidCallback f) => ChipFiltro(rotulo: r, ativo: ativo, onTap: f);
    void cat(CategoriaMaterial c) => setState(() {
      _filtro = _Filtro.categoria;
      _categoria = c;
    });
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Todos', _filtro == _Filtro.todos, () => setState(() => _filtro = _Filtro.todos)),
        for (final c in CategoriaMaterial.values)
          chip(c.plural, _filtro == _Filtro.categoria && _categoria == c, () => cat(c)),
        chip('Abaixo do mínimo', _filtro == _Filtro.minimo, () => setState(() => _filtro = _Filtro.minimo)),
        chip('Novos', _filtro == _Filtro.novos, () => setState(() => _filtro = _Filtro.novos)),
      ],
    );
  }

  Widget _tabela(List<MaterialEstoque> lista, String? selecionado) {
    const flex = [17, 8, 9, 9];
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
                if (_selecionando) const SizedBox(width: 36),
                Expanded(flex: flex[0], child: cab('Material')),
                Expanded(flex: flex[1], child: cab('Categoria')),
                Expanded(flex: flex[2], child: cab('Disponível')),
                Expanded(flex: flex[3], child: cab('Físico · Reserv.')),
              ],
            ),
          ),
          if (lista.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Nenhum material com esse filtro.', style: TextStyle(color: panelSlate)),
            ),
          for (final (i, m) in lista.indexed)
            Cascata(
              key: ValueKey(m.id),
              indice: i,
              child: _LinhaMaterial(
                m: m,
                flex: flex,
                selecionado: m.id == selecionado,
                selecionando: _selecionando,
                marcado: _selecionados.contains(m.id),
                onTap: () {
                  if (_selecionando) {
                    setState(() => _selecionados.contains(m.id) ? _selecionados.remove(m.id) : _selecionados.add(m.id));
                  } else {
                    NavCerebro.ler(context).abrirMaterial(m.id == selecionado ? null : m.id);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

Color corDisponivel(MaterialEstoque m) {
  if (m.disponivel <= 0 && (m.estoqueMinimo > 0 || m.criadoAutomaticamente || m.estoqueFisico <= 0)) {
    return estoqueFalta;
  }
  if (m.abaixoDoMinimo) return estoqueAlerta;
  return dellalioTitle;
}

class _LinhaMaterial extends StatelessWidget {
  final MaterialEstoque m;
  final List<int> flex;
  final bool selecionado;
  final bool selecionando;
  final bool marcado;
  final VoidCallback onTap;
  const _LinhaMaterial({
    required this.m,
    required this.flex,
    required this.selecionado,
    required this.selecionando,
    required this.marcado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sub = m.criadoAutomaticamente && m.origemCriacao != null
        ? m.origemCriacao!
        : [?m.local, if (m.refFornecedor != null) 'ref. ${m.refFornecedor}'].join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: selecionado ? dellalioGold.withValues(alpha: 0.07) : Colors.transparent,
            border: Border(
              top: BorderSide(color: hairlineNavy),
              left: BorderSide(color: selecionado ? dellalioGold : Colors.transparent, width: 3),
            ),
          ),
          child: Row(
            children: [
              if (selecionando)
                SizedBox(
                  width: 36,
                  child: Checkbox(
                    value: marcado,
                    onChanged: (_) => onTap(),
                    activeColor: acaoPrincipal,
                    checkColor: acaoPrincipalTexto,
                  ),
                ),
              Expanded(
                flex: flex[0],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: m.nome, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: panelIvory)),
                        if (m.criadoAutomaticamente) const WidgetSpan(alignment: PlaceholderAlignment.middle, child: SeloNovo()),
                      ]),
                    ),
                    if (sub.isNotEmpty) Text(sub, style: TextStyle(color: panelSlateDim, fontSize: 12.5)),
                  ],
                ),
              ),
              Expanded(flex: flex[1], child: Text(m.categoria.rotulo, style: TextStyle(color: panelSlateDim, fontSize: 13))),
              Expanded(
                flex: flex[2],
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: fmtNumero(m.disponivel), style: fraunces(22, cor: corDisponivel(m))),
                    TextSpan(text: ' ${m.unidade.sigla}', style: fraunces(13, cor: panelSlateDim)),
                  ]),
                ),
              ),
              Expanded(
                flex: flex[3],
                child: Text(
                  '${fmtNumero(m.estoqueFisico)} · ${fmtNumero(m.estoqueReservado)}',
                  style: TextStyle(color: panelSlateDim, fontSize: 13, fontFeatures: numerosTabulares),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ficha do material: saldos, histórico, onde está reservado e ações.
class FichaMaterial extends StatefulWidget {
  final MaterialEstoque material;
  const FichaMaterial({super.key, required this.material});
  @override
  State<FichaMaterial> createState() => _FichaMaterialState();
}

class _FichaMaterialState extends State<FichaMaterial> {
  int _limite = 20;

  @override
  Widget build(BuildContext context) {
    final m = widget.material;
    final u = m.unidade;
    Widget card(String rotulo, double v, Color cor) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: inkSurface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hairlineNavy),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RotuloCaixaAlta(rotulo),
            const SizedBox(height: 6),
            NumeroAnimado(valor: v, formatar: fmtNumero, estilo: fraunces(30, cor: cor)),
          ],
        ),
      ),
    );

    final cabecalho = [m.categoria.rotulo, if (m.refFornecedor != null) 'ref. ${m.refFornecedor}', ?m.local].join(' · ');
    final estadoMinimo = m.abaixoDoMinimo ? 'abaixo do mínimo · no pedido' : null;

    return Container(
      width: 470,
      decoration: BoxDecoration(
        color: inkSurface,
        border: Border(left: BorderSide(color: hairlineNavy)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(26),
        children: [
          Row(
            children: [
              Expanded(child: Text(cabecalho, style: TextStyle(color: panelSlateDim, fontSize: 12.5))),
              IconButton(
                tooltip: 'Fechar',
                onPressed: () => NavCerebro.ler(context).abrirMaterial(null),
                icon: Icon(Icons.close, size: 18, color: panelSlate),
              ),
            ],
          ),
          Text(m.nome, style: fraunces(30)),
          const SizedBox(height: 16),
          Row(
            children: [
              card('Físico', m.estoqueFisico, dellalioTitle),
              const SizedBox(width: 10),
              card('Reservado', m.estoqueReservado, estoqueAlerta),
              const SizedBox(width: 10),
              card('Disponível', m.disponivel, estoqueOuro),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mínimo ${fmtQtd(m.estoqueMinimo, u)} · custo médio ${fmtMoeda(m.custoMedio)}',
                  style: TextStyle(color: panelSlateDim, fontSize: 12.5),
                ),
              ),
              if (estadoMinimo != null) Text(estadoMinimo, style: TextStyle(color: estoqueAlerta, fontSize: 12.5)),
            ],
          ),
          if (m.criadoAutomaticamente) ...[
            const SizedBox(height: 14),
            BordaTracejada(
              cor: estoqueOuro.withValues(alpha: 0.6),
              fundo: dellalioGold.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${m.origemCriacao ?? 'Criado automaticamente'}. Quer completar mínimo, local e dimensões?',
                        style: TextStyle(color: panelSlate, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    BotaoEstoque(rotulo: 'Completar', pequeno: true, onPressed: () => editarMaterial(context, m: m)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BotaoEstoque(rotulo: 'Ajustar saldo', pequeno: true, onPressed: () => ajustarSaldo(context, m)),
              BotaoEstoque(rotulo: 'Editar', variante: VarianteBotao.fantasma, pequeno: true, onPressed: () => editarMaterial(context, m: m)),
              BotaoEstoque(rotulo: 'Etiqueta QR', variante: VarianteBotao.fantasma, pequeno: true, onPressed: () => imprimirEtiquetas([m])),
              BotaoEstoque(
                rotulo: 'Desativar',
                variante: VarianteBotao.fantasma,
                pequeno: true,
                onPressed: () async {
                  final ok = await perguntar(
                    context,
                    titulo: 'Desativar material',
                    texto: '${m.nome} some das listas e do casamento automático. O histórico continua.',
                    sim: 'Desativar',
                    perigo: true,
                  );
                  if (ok == true) {
                    await CadastroService.instancia.definirAtivo(m.id, false);
                    if (context.mounted) NavCerebro.ler(context).abrirMaterial(null);
                  }
                },
              ),
            ],
          ),
          _OndeReservado(m),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Text('Histórico', style: fraunces(18))),
              Text('20 por vez', style: TextStyle(color: panelSlateDim, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Movimentacao>>(
            key: ValueKey(_limite),
            stream: Consultas.instancia.movimentacoesDoMaterial(m.id, limite: _limite),
            builder: (context, snap) {
              if (snap.hasError) return ErroConsulta(snap.error!);
              if (!snap.hasData) return const Carregando();
              final movs = snap.data!;
              if (movs.isEmpty) return Text('Sem movimentações ainda.', style: TextStyle(color: panelSlate));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, mv) in movs.indexed)
                    Cascata(
                      key: ValueKey(mv.id),
                      indice: i,
                      child: ItemLinhaTempo(
                        cor: corTipoMov(mv.tipo),
                        titulo: tituloMov(mv),
                        quantidade: qtdMov(mv),
                        detalhe: detalheMov(mv),
                        ultimo: i == movs.length - 1,
                        tituloColorido: mv.tipo != TipoMovimentacao.perda && mv.tipo != TipoMovimentacao.ajuste,
                      ),
                    ),
                  if (movs.length >= _limite)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BotaoEstoque(
                        rotulo: 'Mais 20',
                        pequeno: true,
                        variante: VarianteBotao.fantasma,
                        onPressed: () => setState(() => _limite += 20),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OndeReservado extends StatelessWidget {
  final MaterialEstoque m;
  const _OndeReservado(this.m);

  @override
  Widget build(BuildContext context) {
    if (m.estoqueReservado <= 0) return const SizedBox.shrink();
    return StreamBuilder<List<ListaCorte>>(
      stream: Consultas.instancia.listasAtivas(),
      builder: (context, snap) {
        final reservas = [
          for (final l in snap.data ?? const <ListaCorte>[])
            for (final i in l.itens)
              if (i.materialId == m.id && i.qtdReservada > 0) (l, i.qtdReservada),
        ];
        if (reservas.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Onde está reservado', style: fraunces(18)),
              const SizedBox(height: 8),
              for (final (l, q) in reservas)
                InkWell(
                  onTap: () => NavCerebro.ler(context).abrirLista(l.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(child: Text(l.titulo, style: TextStyle(color: panelIvory, fontWeight: FontWeight.w600))),
                        Text(fmtQtd(q, m.unidade), style: TextStyle(color: estoqueAlerta, fontWeight: FontWeight.w600, fontFeatures: numerosTabulares)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
