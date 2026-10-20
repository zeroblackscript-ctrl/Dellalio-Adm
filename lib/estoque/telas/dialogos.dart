import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../models/models.dart';
import '../notas/importador_notas.dart';
import '../services/aviso_service.dart';
import '../services/cadastro_service.dart';
import '../services/consultas.dart';
import '../services/estoque_service.dart';
import '../services/lista_service.dart';
import '../services/pedido_service.dart';
import '../ui/kit_estoque.dart';
import '../util/datas.dart';
import '../util/normalizar.dart';
import '../util/quantidade.dart';
import 'nav_cerebro.dart';

/// Moldura comum dos diálogos do Cérebro.
class _Moldura extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget child;
  final List<Widget> acoes;
  final double largura;
  const _Moldura({
    required this.titulo,
    this.subtitulo,
    required this.child,
    this.acoes = const [],
    this.largura = 520,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: inkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: hairlineNavy),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largura, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(titulo, style: fraunces(24))),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 18, color: panelSlate),
                  ),
                ],
              ),
              if (subtitulo != null)
                Text(subtitulo!, style: TextStyle(color: panelSlate, fontSize: 13)),
              const SizedBox(height: 16),
              Flexible(child: child),
              if (acoes.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final (i, a) in acoes.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      a,
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _campo(String rotulo, {String? sufixo}) => InputDecoration(
  labelText: rotulo,
  suffixText: sufixo,
  labelStyle: TextStyle(color: panelSlate, fontSize: 13),
  filled: true,
  fillColor: inkSurface2,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: hairlineNavy),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: estoqueOuro, width: 1.4),
  ),
);

TextStyle get _texto => TextStyle(color: panelIvory, fontSize: 14);

double? _num(String s) => double.tryParse(s.trim().replaceAll('.', '').replaceAll(',', '.'));

String _numTexto(double? v) => v == null ? '' : fmtNumero(v).replaceAll('.', '');

// ================================================================ avisos

Future<void> abrirAvisos(BuildContext context) => showDialog(
  context: context,
  builder: (ctx) => _Moldura(
    titulo: 'Avisos',
    largura: 520,
    acoes: [
      BotaoEstoque(
        rotulo: 'Marcar todos como lidos',
        variante: VarianteBotao.fantasma,
        pequeno: true,
        onPressed: () => AvisoService().marcarTodosLidos(),
      ),
    ],
    child: StreamBuilder<List<Aviso>>(
      stream: AvisoService().recentes(),
      builder: (context, snap) {
        if (snap.hasError) return ErroConsulta(snap.error!);
        if (!snap.hasData) return const Carregando();
        final avisos = snap.data!;
        if (avisos.isEmpty) {
          return Text('Nada por aqui.', style: TextStyle(color: panelSlate));
        }
        return ListView.separated(
          shrinkWrap: true,
          itemCount: avisos.length,
          separatorBuilder: (_, _) => Divider(color: hairlineNavy, height: 1),
          itemBuilder: (context, i) {
            final a = avisos[i];
            final (icone, cor) = switch (a.tipo) {
              TipoAviso.listaLida => (Icons.description_outlined, estoqueOuro),
              TipoAviso.confirmar => (Icons.help_outline, estoqueOuro),
              TipoAviso.pedidoPronto => (Icons.shopping_cart_outlined, estoqueAlerta),
              TipoAviso.listaPronta => (Icons.check_circle_outline, estoqueOk),
              TipoAviso.notaLancada => (Icons.receipt_long_outlined, estoqueOk),
              TipoAviso.alerta => (Icons.warning_amber_rounded, estoqueFalta),
            };
            return Cascata(
              indice: i,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(icone, color: cor, size: 20),
                title: Text(
                  a.texto,
                  style: TextStyle(
                    color: panelIvory,
                    fontSize: 13.5,
                    fontWeight: a.lido ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
                subtitle: Text(fmtQuando(a.criadoEm), style: TextStyle(color: panelSlateDim, fontSize: 12)),
                trailing: a.lido
                    ? null
                    : Container(width: 8, height: 8, decoration: BoxDecoration(color: dellalioGold, shape: BoxShape.circle)),
                onTap: () {
                  AvisoService().marcarLido(a.id);
                  final nav = NavCerebro.ler(context);
                  Navigator.pop(ctx);
                  if (a.listaCorteId != null) {
                    nav.abrirLista(a.listaCorteId!);
                  } else if (a.pedidoId != null) {
                    nav.ir(SecaoCerebro.pedidos, pedidoId: a.pedidoId);
                  } else if (a.notaFiscalId != null) {
                    abrirNota(context, a.notaFiscalId!);
                  }
                },
              ),
            );
          },
        );
      },
    ),
  ),
);

// ===================================================== escolher material

/// Busca de material com as [sugestoes] primeiro. Devolve o id, ou
/// [criarNovo] quando escolheram "Criar material novo".
const String criarNovo = '__novo__';

Future<String?> escolherMaterial(
  BuildContext context, {
  String titulo = 'Escolher material',
  String? textoOriginal,
  List<SugestaoMaterial> sugestoes = const [],
  bool permitirNovo = true,
}) => showDialog<String>(
  context: context,
  builder: (ctx) => _EscolherMaterial(
    titulo: titulo,
    textoOriginal: textoOriginal,
    sugestoes: sugestoes,
    permitirNovo: permitirNovo,
  ),
);

class _EscolherMaterial extends StatefulWidget {
  final String titulo;
  final String? textoOriginal;
  final List<SugestaoMaterial> sugestoes;
  final bool permitirNovo;
  const _EscolherMaterial({
    required this.titulo,
    this.textoOriginal,
    required this.sugestoes,
    required this.permitirNovo,
  });

  @override
  State<_EscolherMaterial> createState() => _EscolherMaterialState();
}

class _EscolherMaterialState extends State<_EscolherMaterial> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    return _Moldura(
      titulo: widget.titulo,
      subtitulo: widget.textoOriginal == null ? null : 'Na lista: "${widget.textoOriginal}"',
      largura: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BuscaEstoque(autofocus: true, onChanged: (v) => setState(() => _busca = normalizar(v))),
          const SizedBox(height: 12),
          Flexible(
            child: StreamBuilder<List<MaterialEstoque>>(
              stream: Consultas.instancia.materiais(),
              builder: (context, snap) {
                if (!snap.hasData) return const Carregando();
                final porId = {for (final m in snap.data!) m.id: m};
                final sugeridos = [
                  for (final s in widget.sugestoes)
                    if (porId[s.materialId] case final m?) (m, s.score),
                ];
                final ids = sugeridos.map((e) => e.$1.id).toSet();
                final outros = snap.data!.where((m) {
                  if (ids.contains(m.id) && _busca.isEmpty) return false;
                  return _busca.isEmpty || normalizar('${m.nome} ${m.refFornecedor ?? ''}').contains(_busca);
                });
                final linhas = <(MaterialEstoque, double?)>[
                  if (_busca.isEmpty) ...sugeridos,
                  for (final m in outros) (m, null),
                ];
                return ListView(
                  shrinkWrap: true,
                  children: [
                    if (widget.permitirNovo)
                      ListTile(
                        leading: Icon(Icons.add_circle_outline, color: estoqueOuro),
                        title: Text('Criar material novo', style: TextStyle(color: estoqueOuro, fontWeight: FontWeight.w600)),
                        subtitle: widget.textoOriginal == null
                            ? null
                            : Text('com a descrição da lista', style: TextStyle(color: panelSlateDim, fontSize: 12)),
                        onTap: () => Navigator.pop(context, criarNovo),
                      ),
                    for (final (m, score) in linhas.take(60))
                      ListTile(
                        dense: true,
                        title: Text(m.nome, style: TextStyle(color: panelIvory, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [m.categoria.rotulo, ?m.refFornecedor, ?m.local, 'disp. ${fmtQtd(m.disponivel, m.unidade)}'].join(' · '),
                          style: TextStyle(color: panelSlateDim, fontSize: 12),
                        ),
                        trailing: score == null
                            ? null
                            : PilulaStatus(rotulo: '${(score * 100).round()}% parecido', cor: estoqueOuro, pequena: true),
                        onTap: () => Navigator.pop(context, m.id),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================== ajustar saldo

Future<void> ajustarSaldo(BuildContext context, MaterialEstoque m) => showDialog(
  context: context,
  builder: (_) => _AjustarSaldo(m),
);

class _AjustarSaldo extends StatefulWidget {
  final MaterialEstoque m;
  const _AjustarSaldo(this.m);
  @override
  State<_AjustarSaldo> createState() => _AjustarSaldoState();
}

class _AjustarSaldoState extends State<_AjustarSaldo> {
  late final TextEditingController _qtd = TextEditingController(text: _numTexto(widget.m.estoqueFisico));
  final TextEditingController _outro = TextEditingController();
  String _motivo = 'Inventário';
  bool _salvando = false;

  static const _motivos = ['Inventário', 'Chapa danificada', 'Erro de lançamento', 'Outro'];

  Future<void> _salvar() async {
    final v = _num(_qtd.text);
    if (v == null || v < 0) return;
    setState(() => _salvando = true);
    try {
      await EstoqueService().ajustar(
        materialId: widget.m.id,
        novoFisico: v,
        motivo: _motivo == 'Outro' && _outro.text.trim().isNotEmpty ? _outro.text.trim() : _motivo,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) avisar(context, 'Não ajustou: $e', erro: true);
      setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Moldura(
      titulo: 'Ajustar saldo',
      subtitulo: '${widget.m.nome} · físico hoje ${fmtQtd(widget.m.estoqueFisico, widget.m.unidade)}',
      acoes: [
        BotaoEstoque(rotulo: 'Cancelar', variante: VarianteBotao.fantasma, onPressed: () => Navigator.pop(context)),
        BotaoEstoque(rotulo: 'Salvar ajuste', variante: VarianteBotao.principal, icone: Icons.check, carregando: _salvando, onPressed: _salvar),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _qtd,
            autofocus: true,
            style: fraunces(28),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _campo('Novo físico (contado)', sufixo: widget.m.unidade.sigla),
            onSubmitted: (_) => _salvar(),
          ),
          const SizedBox(height: 16),
          RotuloCaixaAlta('Motivo'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _motivos)
                ChipFiltro(rotulo: m, ativo: _motivo == m, onTap: () => setState(() => _motivo = m)),
            ],
          ),
          if (_motivo == 'Outro') ...[
            const SizedBox(height: 12),
            TextField(controller: _outro, style: _texto, decoration: _campo('Qual?')),
          ],
        ],
      ),
    );
  }
}

// ======================================================= editar material

/// Cria ([m] nulo) ou edita os dados de cadastro de um material.
Future<String?> editarMaterial(BuildContext context, {MaterialEstoque? m}) =>
    showDialog<String>(context: context, builder: (_) => _EditarMaterial(m));

class _EditarMaterial extends StatefulWidget {
  final MaterialEstoque? m;
  const _EditarMaterial(this.m);
  @override
  State<_EditarMaterial> createState() => _EditarMaterialState();
}

class _EditarMaterialState extends State<_EditarMaterial> {
  late final _nome = TextEditingController(text: widget.m?.nome ?? '');
  late final _ref = TextEditingController(text: widget.m?.refFornecedor ?? '');
  late final _local = TextEditingController(text: widget.m?.local ?? '');
  late final _cor = TextEditingController(text: widget.m?.cor ?? '');
  late final _minimo = TextEditingController(text: _numTexto(widget.m?.estoqueMinimo));
  late final _esp = TextEditingController(text: _numTexto(widget.m?.espessuraMm));
  late final _larg = TextEditingController(text: _numTexto(widget.m?.larguraMm));
  late final _alt = TextEditingController(text: _numTexto(widget.m?.alturaMm));
  final _saldo = TextEditingController();
  final _custo = TextEditingController();
  late CategoriaMaterial _cat = widget.m?.categoria ?? CategoriaMaterial.chapa;
  late UnidadeEstoque _un = widget.m?.unidade ?? UnidadeEstoque.ch;
  late String? _fornecedorId = widget.m?.fornecedorId;
  bool _salvando = false;

  bool get _novo => widget.m == null;

  Future<void> _salvar() async {
    if (_nome.text.trim().isEmpty) return;
    setState(() => _salvando = true);
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    try {
      if (_novo) {
        final id = await CadastroService.instancia.criarMaterial(
          MaterialEstoque(
            id: '',
            nome: _nome.text.trim(),
            categoria: _cat,
            unidade: _un,
            refFornecedor: t(_ref),
            local: t(_local),
            cor: t(_cor),
            estoqueMinimo: _num(_minimo.text) ?? 0,
            espessuraMm: _num(_esp.text),
            larguraMm: _num(_larg.text),
            alturaMm: _num(_alt.text),
            fornecedorId: _fornecedorId,
          ),
          saldoInicial: _num(_saldo.text) ?? 0,
          custo: _num(_custo.text),
        );
        if (mounted) Navigator.pop(context, id);
      } else {
        await CadastroService.instancia.atualizarMaterial(widget.m!.id, {
          'nome': _nome.text.trim(),
          'categoria': _cat.name,
          'unidade': _un.name,
          'refFornecedor': t(_ref),
          'local': t(_local),
          'cor': t(_cor),
          'estoqueMinimo': _num(_minimo.text) ?? 0,
          'espessuraMm': _num(_esp.text),
          'larguraMm': _num(_larg.text),
          'alturaMm': _num(_alt.text),
          'fornecedorId': _fornecedorId,
        });
        if (mounted) Navigator.pop(context, widget.m!.id);
      }
    } catch (e) {
      if (mounted) avisar(context, 'Não salvou: $e', erro: true);
      setState(() => _salvando = false);
    }
  }

  Widget _linha(List<Widget> filhos) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        for (final (i, f) in filhos.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: f),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final chapa = _cat == CategoriaMaterial.chapa || _cat == CategoriaMaterial.sobra;
    return _Moldura(
      titulo: _novo ? 'Novo material' : 'Editar material',
      subtitulo: widget.m?.criadoAutomaticamente == true
          ? 'Criado automaticamente — completar mínimo, local e dimensões é opcional.'
          : null,
      largura: 600,
      acoes: [
        BotaoEstoque(rotulo: 'Cancelar', variante: VarianteBotao.fantasma, onPressed: () => Navigator.pop(context)),
        BotaoEstoque(rotulo: 'Salvar', variante: VarianteBotao.principal, icone: Icons.check, carregando: _salvando, onPressed: _salvar),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _linha([TextField(controller: _nome, autofocus: _novo, style: _texto, decoration: _campo('Nome'))]),
            _linha([
              DropdownButtonFormField<CategoriaMaterial>(
                initialValue: _cat,
                dropdownColor: inkSurface,
                style: textoUi(context, tamanho: 14),
                decoration: _campo('Categoria'),
                items: [for (final c in CategoriaMaterial.values) DropdownMenuItem(value: c, child: Text(c.rotulo))],
                onChanged: (v) => setState(() => _cat = v ?? _cat),
              ),
              DropdownButtonFormField<UnidadeEstoque>(
                initialValue: _un,
                dropdownColor: inkSurface,
                style: textoUi(context, tamanho: 14),
                decoration: _campo('Unidade de estoque'),
                items: [for (final u in UnidadeEstoque.values) DropdownMenuItem(value: u, child: Text('${u.sigla} · ${u.singular}'))],
                onChanged: (v) => setState(() => _un = v ?? _un),
              ),
            ]),
            _linha([
              TextField(controller: _ref, style: _texto, decoration: _campo('Referência do fornecedor')),
              StreamBuilder<List<Fornecedor>>(
                stream: Consultas.instancia.fornecedores(),
                builder: (context, snap) {
                  final fs = snap.data ?? const <Fornecedor>[];
                  return DropdownButtonFormField<String?>(
                    initialValue: fs.any((f) => f.id == _fornecedorId) ? _fornecedorId : null,
                    dropdownColor: inkSurface,
                    style: textoUi(context, tamanho: 14),
                    decoration: _campo('Fornecedor'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Sem fornecedor')),
                      for (final f in fs) DropdownMenuItem<String?>(value: f.id, child: Text(f.nome)),
                    ],
                    onChanged: (v) => setState(() => _fornecedorId = v),
                  );
                },
              ),
            ]),
            _linha([
              TextField(controller: _local, style: _texto, decoration: _campo('Local (baia/prateleira)')),
              TextField(controller: _cor, style: _texto, decoration: _campo('Cor / padrão')),
              TextField(controller: _minimo, style: _texto, decoration: _campo('Mínimo', sufixo: _un.sigla)),
            ]),
            _linha([
              TextField(controller: _esp, style: _texto, decoration: _campo('Espessura', sufixo: 'mm')),
              if (chapa) TextField(controller: _larg, style: _texto, decoration: _campo('Largura', sufixo: 'mm')),
              if (chapa) TextField(controller: _alt, style: _texto, decoration: _campo('Altura', sufixo: 'mm')),
            ]),
            if (_novo)
              _linha([
                TextField(controller: _saldo, style: _texto, decoration: _campo('Saldo inicial', sufixo: _un.sigla)),
                TextField(controller: _custo, style: _texto, decoration: _campo('Custo unitário', sufixo: 'R\$')),
              ]),
          ],
        ),
      ),
    );
  }
}

// ========================================================= fornecedores

Future<Fornecedor?> editarFornecedor(BuildContext context, {Fornecedor? f}) =>
    showDialog<Fornecedor>(context: context, builder: (_) => _EditarFornecedor(f));

class _EditarFornecedor extends StatefulWidget {
  final Fornecedor? f;
  const _EditarFornecedor(this.f);
  @override
  State<_EditarFornecedor> createState() => _EditarFornecedorState();
}

class _EditarFornecedorState extends State<_EditarFornecedor> {
  late final _nome = TextEditingController(text: widget.f?.nome ?? '');
  late final _cnpj = TextEditingController(text: widget.f?.cnpj ?? '');
  late final _whats = TextEditingController(text: widget.f?.whatsapp ?? '');
  late final _email = TextEditingController(text: widget.f?.email ?? '');
  late final _desc = TextEditingController(text: widget.f?.descricao ?? '');

  Future<void> _salvar() async {
    if (_nome.text.trim().isEmpty) return;
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    var whats = _whats.text.replaceAll(RegExp(r'\D'), '');
    if (whats.isNotEmpty && !whats.startsWith('55') && whats.length <= 11) whats = '55$whats';
    final f = Fornecedor(
      id: widget.f?.id ?? '',
      nome: _nome.text.trim(),
      cnpj: t(_cnpj)?.replaceAll(RegExp(r'\D'), ''),
      whatsapp: whats.isEmpty ? null : whats,
      email: t(_email),
      descricao: t(_desc),
      codigosProduto: widget.f?.codigosProduto ?? const {},
    );
    final id = await CadastroService.instancia.salvarFornecedor(f);
    if (mounted) Navigator.pop(context, Fornecedor.fromMap(id, f.toMap()));
  }

  @override
  Widget build(BuildContext context) {
    Widget c(TextEditingController ctl, String r) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: ctl, style: _texto, decoration: _campo(r)),
    );
    return _Moldura(
      titulo: widget.f == null ? 'Novo fornecedor' : 'Fornecedor',
      acoes: [
        BotaoEstoque(rotulo: 'Cancelar', variante: VarianteBotao.fantasma, onPressed: () => Navigator.pop(context)),
        BotaoEstoque(rotulo: 'Salvar', variante: VarianteBotao.principal, icone: Icons.check, onPressed: _salvar),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            c(_nome, 'Nome'),
            c(_cnpj, 'CNPJ'),
            c(_whats, 'WhatsApp (DDD + número)'),
            c(_email, 'E-mail'),
            c(_desc, 'O que fornece (ex.: chapas e fitas)'),
          ],
        ),
      ),
    );
  }
}

/// Lista de fornecedores pra escolher, com "Novo fornecedor".
Future<Fornecedor?> escolherFornecedor(BuildContext context) => showDialog<Fornecedor>(
  context: context,
  builder: (ctx) => _Moldura(
    titulo: 'Escolher fornecedor',
    child: StreamBuilder<List<Fornecedor>>(
      stream: Consultas.instancia.fornecedores(),
      builder: (context, snap) {
        if (!snap.hasData) return const Carregando();
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: estoqueOuro),
              title: Text('Novo fornecedor', style: TextStyle(color: estoqueOuro, fontWeight: FontWeight.w600)),
              onTap: () async {
                final f = await editarFornecedor(context);
                if (f != null && ctx.mounted) Navigator.pop(ctx, f);
              },
            ),
            for (final f in snap.data!)
              ListTile(
                title: Text(f.nome, style: TextStyle(color: panelIvory, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [?f.whatsappFormatado, ?f.descricao].join(' · '),
                  style: TextStyle(color: panelSlateDim, fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        );
      },
    ),
  ),
);

// ================================================================= nota

Future<void> abrirNota(BuildContext context, String notaId) => showDialog(
  context: context,
  builder: (_) => _NotaDialogo(notaId),
);

class _NotaDialogo extends StatelessWidget {
  final String notaId;
  const _NotaDialogo(this.notaId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NotaFiscal?>(
      stream: Consultas.instancia.nota(notaId),
      builder: (context, snap) {
        final n = snap.data;
        if (n == null) {
          return const _Moldura(titulo: 'Nota fiscal', child: Carregando());
        }
        return _Moldura(
          titulo: 'NF ${n.numero} · ${n.fornecedorNome}',
          subtitulo: '${fmtCompleta(n.emitidaEm)} · ${n.status.rotulo}',
          largura: 680,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (i, it) in n.itens.indexed) _ItemNotaLinha(nota: n, indice: i, item: it),
            ],
          ),
        );
      },
    );
  }
}

class _ItemNotaLinha extends StatefulWidget {
  final NotaFiscal nota;
  final int indice;
  final ItemNota item;
  const _ItemNotaLinha({required this.nota, required this.indice, required this.item});
  @override
  State<_ItemNotaLinha> createState() => _ItemNotaLinhaState();
}

class _ItemNotaLinhaState extends State<_ItemNotaLinha> {
  final _fator = TextEditingController();
  bool _ocupado = false;

  Future<void> _rodar(Future<void> Function() f) async {
    setState(() => _ocupado = true);
    try {
      await f();
    } catch (e) {
      if (mounted) avisar(context, 'Não deu: $e', erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final pendente = it.situacao == SituacaoItemNota.confirmar;
    final embalagem = pendente && (it.pergunta?.startsWith('Quantos') ?? false);
    final linha = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.materialNome ?? it.descricao, style: TextStyle(color: panelIvory, fontWeight: FontWeight.w600)),
                    Text(
                      'Na nota: ${it.descricao} · ${fmtNumero(it.quantidade)} ${it.unidadeComercial} · ${fmtMoeda(it.valorUnitario)}',
                      style: TextStyle(color: panelSlateDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PilulaStatus(
                rotulo: pendente ? 'Confirmar' : 'Lançado',
                cor: pendente ? estoqueOuro : estoqueOk,
              ),
            ],
          ),
          if (pendente) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text(it.pergunta ?? '', style: TextStyle(color: panelIvory, fontSize: 14))),
                if (embalagem) ...[
                  SizedBox(
                    width: 110,
                    child: TextField(controller: _fator, style: _texto, decoration: _campo('Qtd.')),
                  ),
                  const SizedBox(width: 8),
                  BotaoEstoque(
                    rotulo: 'Lançar',
                    variante: VarianteBotao.principal,
                    pequeno: true,
                    carregando: _ocupado,
                    onPressed: () {
                      final f = _num(_fator.text);
                      if (f == null || f <= 0) return;
                      _rodar(() => ImportadorNotas.instancia.responderEmbalagem(widget.nota.id, widget.indice, f));
                    },
                  ),
                ] else ...[
                  BotaoEstoque(
                    rotulo: 'Sim',
                    icone: Icons.check,
                    variante: VarianteBotao.principal,
                    pequeno: true,
                    carregando: _ocupado,
                    onPressed: () => _rodar(() => ImportadorNotas.instancia.confirmarItem(widget.nota.id, widget.indice, it.materialId!)),
                  ),
                  const SizedBox(width: 8),
                  BotaoEstoque(
                    rotulo: 'Escolher outro',
                    pequeno: true,
                    onPressed: () async {
                      final id = await escolherMaterial(context, textoOriginal: it.descricao, permitirNovo: false);
                      if (id != null) _rodar(() => ImportadorNotas.instancia.confirmarItem(widget.nota.id, widget.indice, id));
                    },
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: hairlineNavy))),
      child: linha,
    );
  }
}

// ====================================================== cortar / enviar

/// "Marcar como cortado": confirmação + pergunta das faltas, uma vez só.
Future<bool> cortarLista(BuildContext context, ListaCorte l) async {
  final ok = await perguntar(
    context,
    titulo: 'Marcar como cortado',
    texto: 'Dar baixa nos materiais da ${l.titulo}? O que estava reservado sai do estoque como produção.',
    sim: 'Dar baixa',
  );
  if (ok != true || !context.mounted) return false;
  var porFora = false;
  final faltas = ListaService.faltasPendentes(l);
  if (faltas.isNotEmpty) {
    final r = await perguntar(
      context,
      titulo: 'Faltava material',
      texto: 'Faltavam ${faltas.length} ${faltas.length == 1 ? 'item' : 'itens'} '
          '(${faltas.map((i) => '${fmtNumero(i.qtdFaltante)} ${i.unidade?.sigla ?? ''} ${i.materialNome ?? i.descricaoOriginal}').join(', ')}). '
          'Foram comprados por fora?',
      sim: 'Sim, comprados por fora',
      nao: 'Não',
    );
    if (r == null) return false;
    porFora = r;
  }
  await ListaService().marcarCortada(l.id, compradoPorFora: porFora);
  if (context.mounted) avisar(context, 'Baixa feita: ${l.titulo}.');
  return true;
}

/// Envia pelo WhatsApp (ou copia a mensagem se não tiver número).
Future<void> enviarPedido(BuildContext context, PedidoCompra p) async {
  Fornecedor? f;
  if (p.fornecedorId != null) {
    final d = await FirebaseFirestore.instance.collection('fornecedores').doc(p.fornecedorId).get();
    if (d.exists) f = Fornecedor.fromFirestore(d);
  }
  final abriu = await PedidoService().enviarWhatsApp(p, f);
  if (!context.mounted) return;
  avisar(
    context,
    abriu
        ? 'Pedido da ${p.fornecedorNome} aberto no WhatsApp e marcado como enviado.'
        : '${p.fornecedorNome} sem WhatsApp cadastrado: a mensagem foi copiada. Cole onde preferir.',
  );
}

/// Copia texto pra área de transferência com aviso.
Future<void> copiar(BuildContext context, String texto) async {
  await Clipboard.setData(ClipboardData(text: texto));
  if (context.mounted) avisar(context, 'Copiado.');
}
