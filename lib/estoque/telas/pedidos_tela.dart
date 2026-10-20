import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../importacao/automacao.dart';
import '../importacao/vigia_pasta.dart';
import '../models/models.dart';
import '../services/consultas.dart';
import '../services/pedido_service.dart';
import '../ui/kit_estoque.dart';
import '../util/datas.dart';
import '../util/quantidade.dart';
import 'dialogos.dart';

class PedidosTela extends StatefulWidget {
  const PedidosTela({super.key});
  @override
  State<PedidosTela> createState() => _PedidosTelaState();
}

class _PedidosTelaState extends State<PedidosTela> {
  StatusPedido _aba = StatusPedido.rascunho;

  @override
  Widget build(BuildContext context) {
    final c = Consultas.instancia;
    return Vivos(
      key: ValueKey(_aba),
      streams: [
        c.pedidos(StatusPedido.rascunho),
        c.pedidos(StatusPedido.enviado),
        c.pedidos(StatusPedido.recebidoParcial),
        c.pedidos(StatusPedido.recebido),
        c.fornecedores(),
        c.materiais(),
      ],
      builder: (context, v) {
        final rascunhos = (v[0] as List<PedidoCompra>).where((p) => p.itens.isNotEmpty).toList();
        final enviados = [...v[1] as List<PedidoCompra>, ...v[2] as List<PedidoCompra>]
          ..sort((a, b) => (b.enviadoEm ?? DateTime(2100)).compareTo(a.enviadoEm ?? DateTime(2100)));
        final recebidos = (v[3] as List<PedidoCompra>)
          ..sort((a, b) => (b.recebidoEm ?? DateTime(2100)).compareTo(a.recebidoEm ?? DateTime(2100)));
        final fornecedores = {for (final f in v[4] as List<Fornecedor>) f.id: f};
        final materiais = {for (final m in v[5] as List<MaterialEstoque>) m.id: m};
        final mostrados = switch (_aba) {
          StatusPedido.rascunho => rascunhos,
          StatusPedido.recebido => recebidos.take(30).toList(),
          _ => enviados,
        };
        final prontos = rascunhos.where((p) => !p.semFornecedor).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(34, 26, 34, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Cascata(
                indice: 0,
                child: CabecalhoPagina(
                  titulo: 'Pedidos de compra',
                  subtitulo: '$prontos ${prontos == 1 ? 'rascunho pronto' : 'rascunhos prontos'} · '
                      '${enviados.length} ${enviados.length == 1 ? 'enviado aguardando nota' : 'enviados aguardando nota'}',
                  acoes: [
                    for (final (s, r) in const [
                      (StatusPedido.rascunho, 'Rascunhos'),
                      (StatusPedido.enviado, 'Enviados'),
                      (StatusPedido.recebido, 'Recebidos'),
                    ])
                      ChipFiltro(rotulo: r, ativo: _aba == s, onTap: () => setState(() => _aba = s)),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (mostrados.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _aba == StatusPedido.rascunho
                        ? 'Nada a comprar agora. Os pedidos se montam sozinhos com o que falta nas listas e o que cai abaixo do mínimo.'
                        : 'Nenhum pedido aqui.',
                    style: TextStyle(color: panelSlate),
                  ),
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
                        for (final (i, p) in mostrados.indexed)
                          SizedBox(
                            width: largura,
                            child: Cascata(
                              key: ValueKey(p.id),
                              indice: i,
                              child: _CardPedido(
                                pedido: p,
                                fornecedor: p.fornecedorId == null ? null : fornecedores[p.fornecedorId],
                                materiais: materiais,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 22),
              Cascata(indice: 3, child: const _NotasSozinhas()),
            ],
          ),
        );
      },
    );
  }
}

class _CardPedido extends StatelessWidget {
  final PedidoCompra pedido;
  final Fornecedor? fornecedor;
  final Map<String, MaterialEstoque> materiais;
  const _CardPedido({required this.pedido, required this.fornecedor, required this.materiais});

  bool get _rascunho => pedido.status == StatusPedido.rascunho;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final sub = p.semFornecedor
        ? 'Defina o fornecedor para entrar num pedido'
        : [
            ?fornecedor?.whatsappFormatado,
            ?fornecedor?.descricao,
            if (p.enviadoEm != null) 'enviado ${fmtQuando(p.enviadoEm)}',
            if (p.recebidoEm != null) 'recebido ${fmtQuando(p.recebidoEm)}',
          ].join(' · ');
    final (rotulo, cor) = switch (p.status) {
      _ when p.semFornecedor => ('${p.itens.length} ${p.itens.length == 1 ? 'item' : 'itens'}', estoqueNeutro),
      StatusPedido.rascunho => ('Rascunho', estoqueOuro),
      StatusPedido.enviado => ('Enviado', estoqueAlerta),
      StatusPedido.recebidoParcial => ('Recebido parcial', estoqueAlerta),
      StatusPedido.recebido => ('Recebido', estoqueOk),
    };

    final corpo = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(p.semFornecedor ? 'Sem fornecedor' : p.fornecedorNome, style: fraunces(21))),
              PilulaStatus(rotulo: rotulo, cor: cor),
            ],
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(color: panelSlateDim, fontSize: 12.5)),
          ],
          const SizedBox(height: 10),
          for (final i in p.itens) _LinhaItem(pedido: p, item: i, material: materiais[i.materialId], editavel: _rascunho),
          const SizedBox(height: 14),
          if (_rascunho && p.semFornecedor)
            BotaoEstoque(
              rotulo: 'Escolher fornecedor',
              larguraTotal: true,
              onPressed: () async {
                final f = await escolherFornecedor(context);
                if (f != null) await PedidoService().definirFornecedor(p, f);
              },
            )
          else if (_rascunho)
            BotaoEstoque(
              rotulo: 'Enviar no WhatsApp',
              icone: Icons.chat_outlined,
              variante: VarianteBotao.whatsapp,
              larguraTotal: true,
              onPressed: () => enviarPedido(context, p),
            )
          else if (p.status != StatusPedido.recebido)
            Row(
              children: [
                Expanded(
                  child: BotaoEstoque(
                    rotulo: 'Recebido',
                    icone: Icons.inventory_outlined,
                    larguraTotal: true,
                    onPressed: () async {
                      final ok = await perguntar(
                        context,
                        titulo: 'Material recebido',
                        texto: 'Dar entrada em tudo que falta receber deste pedido? '
                            '(Se a nota fiscal for salva na pasta das notas, isto acontece sozinho.)',
                        sim: 'Dar entrada',
                      );
                      if (ok == true) {
                        await PedidoService().marcarRecebido(p);
                        if (context.mounted) avisar(context, 'Entrada feita: pedido da ${p.fornecedorNome}.');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                BotaoEstoque(
                  rotulo: 'Copiar',
                  icone: Icons.copy,
                  variante: VarianteBotao.fantasma,
                  onPressed: () => copiar(context, PedidoService.mensagem(p)),
                ),
              ],
            ),
        ],
      ),
    );

    if (p.semFornecedor) {
      return BordaTracejada(cor: hairlineNavy, raio: 14, fundo: inkSurface, child: corpo);
    }
    return Container(
      decoration: BoxDecoration(
        color: inkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hairlineNavy),
      ),
      child: corpo,
    );
  }
}

class _LinhaItem extends StatefulWidget {
  final PedidoCompra pedido;
  final ItemPedido item;
  final MaterialEstoque? material;
  final bool editavel;
  const _LinhaItem({required this.pedido, required this.item, required this.material, required this.editavel});
  @override
  State<_LinhaItem> createState() => _LinhaItemState();
}

class _LinhaItemState extends State<_LinhaItem> {
  double? _local;
  Timer? _grava;

  @override
  void dispose() {
    _grava?.cancel();
    super.dispose();
  }

  /// Edição inline: atualiza na hora e grava 600 ms depois do último toque.
  void _mudar(double v) {
    setState(() => _local = v);
    _grava?.cancel();
    _grava = Timer(const Duration(milliseconds: 600), () {
      PedidoService().alterarQuantidade(widget.pedido.id, widget.item.materialId, v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    final q = _local ?? i.quantidade;
    final destinos = i.destinos.isEmpty ? (i.origem == OrigemItemPedido.minimo ? 'repor mínimo' : '') : i.destinos.join(', ');
    final daLista = i.porLista.isNotEmpty;
    final semNada = (widget.material?.disponivel ?? 1) <= 0;
    final recebido = widget.pedido.status != StatusPedido.rascunho
        ? ' · recebido ${fmtNumero(i.qtdRecebida)} de ${fmtNumero(i.quantidade)}'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: hairlineNavy))),
      child: Row(
        children: [
          if (widget.editavel)
            StepperCompacto(valor: q, onChanged: _mudar)
          else
            SizedBox(
              width: 54,
              child: Text(fmtNumero(q), style: TextStyle(color: panelIvory, fontWeight: FontWeight.w700, fontFeatures: numerosTabulares)),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.nome, style: TextStyle(color: panelIvory, fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(
                  '${i.unidade.sigla}${destinos.isEmpty ? '' : ' · $destinos'}$recebido',
                  style: TextStyle(color: panelSlateDim, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PilulaStatus(
            rotulo: daLista ? 'lista' : 'mínimo',
            cor: daLista ? (semNada ? estoqueFalta : estoqueAlerta) : estoqueNeutro,
          ),
        ],
      ),
    );
  }
}

class _NotasSozinhas extends StatelessWidget {
  const _NotasSozinhas();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstadoVigia>(
      valueListenable: Automacao.instancia.fonteNotas.vigia.estado,
      builder: (context, v, _) => PainelEstoque(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: hairlineNavy),
              ),
              child: Icon(Icons.file_download_outlined, color: estoqueOuro),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notas fiscais entram sozinhas', style: TextStyle(color: panelIvory, fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(
                    'Salve o XML da nota em ${v.caminho ?? r'Documentos\Dellalio\Notas'}: o estoque recebe, o custo médio '
                    'atualiza e as listas que esperavam viram "prontas".',
                    style: TextStyle(color: panelSlate, fontSize: 13),
                  ),
                ],
              ),
            ),
            PilulaStatus(rotulo: v.ativo ? 'vigiando' : 'parado', cor: v.ativo ? estoqueOk : estoqueFalta),
          ],
        ),
      ),
    );
  }
}

/// Formata quantidade de item de pedido (usado no Gerenciador também).
String qtdPedido(ItemPedido i) => fmtQtd(i.quantidade, i.unidade);
