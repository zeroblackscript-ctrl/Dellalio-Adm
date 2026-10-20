import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../models/models.dart';
import '../services/consultas.dart';
import '../ui/formatos.dart';
import '../ui/kit_estoque.dart';
import '../util/datas.dart';
import '../util/normalizar.dart';
import '../util/quantidade.dart';
import 'dialogos.dart';
import 'nav_cerebro.dart';

enum _Periodo {
  hoje('Hoje', 0),
  semana('7 dias', 7),
  mes('30 dias', 30),
  trimestre('90 dias', 90),
  ano('12 meses', 365);

  const _Periodo(this.rotulo, this.dias);
  final String rotulo;
  final int dias;
}

class MovimentacoesTela extends StatefulWidget {
  const MovimentacoesTela({super.key});
  @override
  State<MovimentacoesTela> createState() => _MovimentacoesTelaState();
}

class _MovimentacoesTelaState extends State<MovimentacoesTela> {
  _Periodo _periodo = _Periodo.mes;
  TipoMovimentacao? _tipo;
  OrigemMovimentacao? _origem;
  String? _responsavel;
  String _material = '';
  String _cliente = '';
  String? _materialId;
  late final TextEditingController _clienteCtl;
  final TextEditingController _materialCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final nav = NavCerebro.ler(context);
    _cliente = nav.filtroCliente ?? '';
    _materialId = nav.filtroMaterialId;
    _clienteCtl = TextEditingController(text: _cliente);
  }

  @override
  void dispose() {
    _clienteCtl.dispose();
    _materialCtl.dispose();
    super.dispose();
  }

  DateTime get _desde {
    final h = DateTime.now();
    final hoje = DateTime(h.year, h.month, h.day);
    return hoje.subtract(Duration(days: _periodo.dias));
  }

  bool _passa(Movimentacao m) {
    if (_tipo != null && m.tipo != _tipo) return false;
    if (_origem != null && m.origem != _origem) return false;
    if (_responsavel != null && m.responsavelNome != _responsavel) return false;
    if (_materialId != null && m.materialId != _materialId) return false;
    if (_material.isNotEmpty && !normalizar(m.materialNome).contains(_material)) return false;
    if (_cliente.isNotEmpty) {
      final quem = normalizar('${m.clienteNome ?? ''} ${m.projetoNome ?? ''}');
      if (!quem.contains(normalizar(_cliente))) return false;
    }
    return true;
  }

  void _filtrarCliente(String nome) => setState(() {
    _cliente = nome;
    _clienteCtl.text = nome;
  });

  Future<void> _exportar(List<Movimentacao> movs) async {
    final linhas = [
      ['Data', 'Tipo', 'Material', 'Quantidade', 'Unidade', 'Motivo', 'Cliente', 'Projeto', 'Origem', 'Documento', 'Responsável', 'Físico antes', 'Físico depois', 'Reservado antes', 'Reservado depois'],
      for (final m in movs)
        [
          fmtCompleta(m.criadoEm),
          m.tipo.rotulo,
          m.materialNome,
          fmtNumero(m.quantidadeComSinal),
          m.unidade.sigla,
          m.motivo,
          m.clienteNome ?? '',
          m.projetoNome ?? '',
          m.origem.rotulo,
          m.listaCorteId ?? (m.notaFiscalId != null ? 'NF ${numeroNota(m.notaFiscalId)}' : m.pedidoId ?? ''),
          m.responsavelNome,
          fmtNumero(m.fisicoAntes),
          fmtNumero(m.fisicoDepois),
          fmtNumero(m.reservadoAntes),
          fmtNumero(m.reservadoDepois),
        ],
    ];
    // `;` e BOM: o Excel brasileiro abre certo.
    final csv = '﻿${const CsvEncoder(fieldDelimiter: ';').convert(linhas)}';
    final caminho = await FilePicker.saveFile(
      dialogTitle: 'Exportar movimentações',
      fileName: 'movimentacoes_${DateTime.now().toIso8601String().substring(0, 10)}.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (caminho == null) return;
    final destino = caminho.toLowerCase().endsWith('.csv') ? caminho : '$caminho.csv';
    await File(destino).writeAsBytes(utf8.encode(csv));
    if (mounted) avisar(context, '${movs.length} movimentações exportadas.');
  }

  void _abrirOrigem(Movimentacao m) {
    final nav = NavCerebro.ler(context);
    if (m.listaCorteId != null) {
      nav.abrirLista(m.listaCorteId!);
    } else if (m.notaFiscalId != null) {
      abrirNota(context, m.notaFiscalId!);
    } else if (m.pedidoId != null) {
      nav.ir(SecaoCerebro.pedidos, pedidoId: m.pedidoId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Movimentacao>>(
      key: ValueKey(_periodo),
      stream: Consultas.instancia.movimentacoesDesde(_desde),
      builder: (context, snap) {
        if (snap.hasError) return ErroConsulta(snap.error!);
        final todas = snap.data ?? const <Movimentacao>[];
        final movs = todas.where(_passa).toList();
        final responsaveis = {for (final m in todas) m.responsavelNome}.toList()..sort();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(34, 26, 34, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Cascata(
                indice: 0,
                child: CabecalhoPagina(
                  titulo: 'Movimentações',
                  subtitulo: 'Livro-razão · ${movs.length} de ${todas.length} no período',
                  acoes: [
                    BotaoEstoque(
                      rotulo: 'Exportar CSV',
                      icone: Icons.download_outlined,
                      onPressed: movs.isEmpty ? null : () => _exportar(movs),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Cascata(indice: 1, child: _filtros(responsaveis)),
              const SizedBox(height: 18),
              Cascata(indice: 2, child: snap.hasData ? _tabela(movs) : const Carregando()),
            ],
          ),
        );
      },
    );
  }

  Widget _filtros(List<String> responsaveis) {
    Widget drop<T>(String rotulo, T? valor, List<(T, String)> opcoes, ValueChanged<T?> f) => Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: inkSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: valor == null ? hairlineNavy : estoqueOuro),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: valor,
          dropdownColor: inkSurface,
          hint: Text(rotulo, style: TextStyle(color: panelSlate, fontSize: 13)),
          style: textoUi(context, tamanho: 13),
          items: [
            DropdownMenuItem<T?>(value: null, child: Text('$rotulo: todos')),
            for (final (v, r) in opcoes) DropdownMenuItem<T?>(value: v, child: Text(r)),
          ],
          onChanged: f,
        ),
      ),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in _Periodo.values)
          ChipFiltro(rotulo: p.rotulo, ativo: _periodo == p, onTap: () => setState(() => _periodo = p)),
        const SizedBox(width: 8),
        drop<TipoMovimentacao>('Tipo', _tipo, [for (final t in TipoMovimentacao.values) (t, t.rotulo)], (v) => setState(() => _tipo = v)),
        drop<OrigemMovimentacao>('Origem', _origem, [for (final o in OrigemMovimentacao.values) (o, o.rotulo)], (v) => setState(() => _origem = v)),
        drop<String>('Responsável', _responsavel, [for (final r in responsaveis) (r, r)], (v) => setState(() => _responsavel = v)),
        BuscaEstoque(
          dica: 'Material',
          largura: 200,
          controller: _materialCtl,
          onChanged: (v) => setState(() {
            _material = normalizar(v);
            _materialId = null;
          }),
        ),
        BuscaEstoque(
          dica: 'Cliente / projeto',
          largura: 200,
          controller: _clienteCtl,
          onChanged: (v) => setState(() => _cliente = v),
        ),
        if (_materialId != null)
          ChipFiltro(rotulo: 'Só este material ✕', ativo: true, onTap: () => setState(() => _materialId = null)),
      ],
    );
  }

  Widget _tabela(List<Movimentacao> movs) {
    const flex = [9, 9, 20, 8, 16, 12, 9];
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
                for (final (i, t) in const ['Data', 'Tipo', 'Material', 'Qtd.', 'Para quem / motivo', 'Origem', 'Quem'].indexed)
                  Expanded(flex: flex[i], child: cab(t)),
              ],
            ),
          ),
          if (movs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Nenhuma movimentação com esses filtros.', style: TextStyle(color: panelSlate)),
            ),
          for (final (i, m) in movs.take(300).indexed)
            Cascata(
              key: ValueKey(m.id),
              indice: i,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: hairlineNavy))),
                child: Row(
                  children: [
                    Expanded(flex: flex[0], child: Text(fmtDiaHora(m.criadoEm), style: TextStyle(color: panelSlateDim, fontSize: 12.5))),
                    Expanded(flex: flex[1], child: Text(m.tipo.rotulo, style: TextStyle(color: corTipoMov(m.tipo), fontSize: 13.5))),
                    Expanded(
                      flex: flex[2],
                      child: InkWell(
                        onTap: () => NavCerebro.ler(context).abrirMaterial(m.materialId),
                        child: Text(m.materialNome, style: TextStyle(color: panelIvory, fontWeight: FontWeight.w600, fontSize: 13.5)),
                      ),
                    ),
                    Expanded(
                      flex: flex[3],
                      child: Text(qtdMov(m), style: TextStyle(color: panelIvory, fontWeight: FontWeight.w600, fontFeatures: numerosTabulares)),
                    ),
                    Expanded(
                      flex: flex[4],
                      child: m.clienteNome == null && m.projetoNome == null
                          ? Text(m.motivo, style: TextStyle(color: panelSlate, fontSize: 13))
                          : InkWell(
                              onTap: () => _filtrarCliente(m.clienteNome ?? m.projetoNome!),
                              child: Text(
                                m.paraQuem!,
                                style: TextStyle(color: estoqueOuro, fontSize: 13, decoration: TextDecoration.underline, decorationColor: estoqueOuro.withValues(alpha: 0.4)),
                              ),
                            ),
                    ),
                    Expanded(
                      flex: flex[5],
                      child: InkWell(
                        onTap: () => _abrirOrigem(m),
                        child: Text(
                          m.notaFiscalId != null ? 'NF ${numeroNota(m.notaFiscalId) ?? ''}' : m.origem.rotulo,
                          style: TextStyle(
                            color: m.listaCorteId != null || m.notaFiscalId != null || m.pedidoId != null ? estoqueOuro : panelSlate,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    Expanded(flex: flex[6], child: Text(m.responsavelNome, style: TextStyle(color: panelSlate, fontSize: 13))),
                  ],
                ),
              ),
            ),
          if (movs.length > 300)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Mostrando 300 de ${movs.length}. O CSV leva todas.', style: TextStyle(color: panelSlateDim, fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}
