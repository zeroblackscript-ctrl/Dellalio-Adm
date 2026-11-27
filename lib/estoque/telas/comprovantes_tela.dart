import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../models/models.dart';
import '../services/consultas.dart';
import '../ui/formatos.dart';
import '../ui/kit_estoque.dart';
import '../util/datas.dart';
import '../util/normalizar.dart';
import 'dialogos.dart';

enum _Periodo {
  semana('7 dias', 7),
  mes('30 dias', 30),
  trimestre('90 dias', 90),
  ano('12 meses', 365);

  const _Periodo(this.rotulo, this.dias);
  final String rotulo;
  final int dias;
}

/// Fichas de retirada (quem recebeu) e de entrada (de onde veio), do
/// celular e do painel. Abre a ficha com assinatura e imprime.
class ComprovantesTela extends StatefulWidget {
  const ComprovantesTela({super.key});
  @override
  State<ComprovantesTela> createState() => _ComprovantesTelaState();
}

class _ComprovantesTelaState extends State<ComprovantesTela> {
  _Periodo _periodo = _Periodo.mes;
  TipoComprovante? _tipo;
  bool _semAssinatura = false;
  String _q = '';

  DateTime get _desde {
    final h = DateTime.now();
    return DateTime(h.year, h.month, h.day).subtract(Duration(days: _periodo.dias));
  }

  bool _passa(Comprovante c) {
    if (_tipo != null && c.tipo != _tipo) return false;
    if (_semAssinatura && (c.tipo != TipoComprovante.retirada || c.assinado)) return false;
    if (_q.isEmpty) return true;
    final texto = normalizar([
      c.numeroFormatado,
      ?c.recebedorNome,
      ?c.recebedorFuncao,
      ?c.origemNome,
      ?c.notaNumero,
      ?c.clienteNome,
      ?c.projetoNome,
      c.motivo,
      c.responsavelNome,
      for (final i in c.itens) i.materialNome,
    ].join(' '));
    return _q.split(' ').every(texto.contains);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Comprovante>>(
      key: ValueKey(_periodo),
      stream: Consultas.instancia.comprovantes(desde: _desde),
      builder: (context, snap) {
        if (snap.hasError) return ErroConsulta(snap.error!);
        final todos = snap.data ?? const <Comprovante>[];
        final lista = todos.where(_passa).toList();
        final retiradas = todos.where((c) => c.tipo == TipoComprovante.retirada).toList();
        final semAssinatura = retiradas.where((c) => !c.assinado).length;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(34, 26, 34, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Cascata(
                indice: 0,
                child: CabecalhoPagina(
                  titulo: 'Comprovantes',
                  subtitulo: '${retiradas.length} retiradas · ${todos.length - retiradas.length} entradas no período'
                      '${semAssinatura > 0 ? ' · $semAssinatura sem assinatura' : ''}',
                  acoes: [
                    BotaoEstoque(
                      rotulo: 'Nova entrada',
                      icone: Icons.move_to_inbox_outlined,
                      onPressed: () => registrarComprovante(context, TipoComprovante.entrada),
                    ),
                    BotaoEstoque(
                      rotulo: 'Nova retirada',
                      icone: Icons.outbox_outlined,
                      variante: VarianteBotao.principal,
                      onPressed: () => registrarComprovante(context, TipoComprovante.retirada),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Cascata(
                indice: 1,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final p in _Periodo.values)
                      ChipFiltro(rotulo: p.rotulo, ativo: _periodo == p, onTap: () => setState(() => _periodo = p)),
                    const SizedBox(width: 8),
                    ChipFiltro(rotulo: 'Todos', ativo: _tipo == null, onTap: () => setState(() => _tipo = null)),
                    for (final t in TipoComprovante.values)
                      ChipFiltro(rotulo: '${t.rotulo}s', ativo: _tipo == t, onTap: () => setState(() => _tipo = t)),
                    ChipFiltro(rotulo: 'Sem assinatura', ativo: _semAssinatura, onTap: () => setState(() => _semAssinatura = !_semAssinatura)),
                    BuscaEstoque(
                      dica: 'Pessoa, material, cliente ou nº',
                      largura: 280,
                      onChanged: (v) => setState(() => _q = normalizar(v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Cascata(indice: 2, child: snap.hasData ? _tabela(lista) : const Carregando()),
            ],
          ),
        );
      },
    );
  }

  Widget _tabela(List<Comprovante> lista) {
    const flex = [7, 10, 9, 22, 18, 13, 10];
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
                for (final (i, t) in const ['Nº', 'Data', 'Tipo', 'Quem recebeu / de onde veio', 'Materiais', 'Cliente / obra', 'Registrou'].indexed)
                  Expanded(flex: flex[i], child: cab(t)),
              ],
            ),
          ),
          if (lista.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Nenhum comprovante com esses filtros. Eles nascem a cada retirada ou entrada feita no celular ou aqui.',
                style: TextStyle(color: panelSlate),
              ),
            ),
          for (final (i, c) in lista.take(300).indexed)
            Cascata(
              key: ValueKey(c.id),
              indice: i,
              child: _Linha(c: c, flex: flex),
            ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final Comprovante c;
  final List<int> flex;
  const _Linha({required this.c, required this.flex});

  @override
  Widget build(BuildContext context) {
    final retirada = c.tipo == TipoComprovante.retirada;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => abrirComprovante(context, c.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: hairlineNavy))),
          child: Row(
            children: [
              Expanded(
                flex: flex[0],
                child: Text(c.numeroFormatado, style: TextStyle(color: estoqueOuro, fontWeight: FontWeight.w700, fontFeatures: numerosTabulares)),
              ),
              Expanded(flex: flex[1], child: Text(fmtDiaHora(c.criadoEm), style: TextStyle(color: panelSlateDim, fontSize: 12.5))),
              Expanded(
                flex: flex[2],
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PilulaStatus(rotulo: c.tipo.rotulo, cor: retirada ? estoqueFalta : estoqueOk, pequena: true),
                ),
              ),
              Expanded(
                flex: flex[3],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.contraparte ?? c.motivo,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: panelIvory, fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                        ),
                        if (retirada && !c.assinado) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Sem assinatura digital',
                            child: Icon(Icons.edit_off_outlined, size: 15, color: estoqueAlerta),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      [?(retirada ? c.recebedorFuncao : (c.notaNumero == null ? null : 'NF ${c.notaNumero}')), c.motivo].join(' · '),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: panelSlateDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: flex[4],
                child: Text(resumoItens(c), overflow: TextOverflow.ellipsis, maxLines: 2, style: TextStyle(color: panelSlate, fontSize: 13)),
              ),
              Expanded(flex: flex[5], child: Text(c.destino ?? '—', overflow: TextOverflow.ellipsis, style: TextStyle(color: panelSlate, fontSize: 13))),
              Expanded(
                flex: flex[6],
                child: Text(
                  [c.responsavelNome.split(' ').first, if (c.registradoNo == 'Gerenciador') 'celular'].join(' · '),
                  style: TextStyle(color: panelSlate, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
