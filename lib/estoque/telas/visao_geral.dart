import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/user_session.dart';
import '../importacao/automacao.dart';
import '../importacao/vigia_pasta.dart';
import '../models/models.dart';
import '../services/consultas.dart';
import '../services/responsavel.dart';
import '../ui/formatos.dart';
import '../ui/kit_estoque.dart';
import '../util/datas.dart';
import '../util/quantidade.dart';
import 'dialogos.dart';
import 'nav_cerebro.dart';

class VisaoGeralTela extends StatelessWidget {
  const VisaoGeralTela({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Consultas.instancia;
    final inicioMes = DateTime(DateTime.now().year, DateTime.now().month);
    return Vivos(
      streams: [
        c.materiais(),
        c.listasAtivas(),
        c.pedidos(StatusPedido.rascunho),
        c.pedidos(StatusPedido.enviado),
        c.notasPendentes(),
        c.listasRecentes(limite: 5),
        c.movimentacoesRecentes(limite: 10),
        c.movimentacoesDesde(inicioMes),
      ],
      builder: (context, v) {
        final materiais = v[0] as List<MaterialEstoque>;
        final ativas = v[1] as List<ListaCorte>;
        final rascunhos = (v[2] as List<PedidoCompra>).where((p) => p.itens.isNotEmpty).toList();
        final enviados = v[3] as List<PedidoCompra>;
        final notas = v[4] as List<NotaFiscal>;
        final recentes = v[5] as List<ListaCorte>;
        final movs = v[6] as List<Movimentacao>;
        final doMes = v[7] as List<Movimentacao>;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(34, 26, 34, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Cascata(indice: 0, child: const _Topo()),
              const SizedBox(height: 22),
              _PrecisaDeVoce(listas: ativas, rascunhos: rascunhos, notas: notas),
              Cascata(
                indice: 2,
                child: _Kpis(
                  materiais: materiais,
                  ativas: ativas,
                  pedidos: [...rascunhos, ...enviados],
                  doMes: doMes,
                ),
              ),
              const SizedBox(height: 22),
              Cascata(
                indice: 3,
                child: LayoutBuilder(
                  builder: (context, cons) {
                    final listas = _ListasRecentes(recentes);
                    final ultimas = _UltimasMovs(movs);
                    if (cons.maxWidth < 900) {
                      return Column(children: [listas, const SizedBox(height: 18), ultimas]);
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 125, child: listas),
                          const SizedBox(width: 18),
                          Expanded(flex: 100, child: ultimas),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Topo extends StatelessWidget {
  const _Topo();

  @override
  Widget build(BuildContext context) {
    final escuro = UserSession.isDarkMode();
    return FutureBuilder<Responsavel>(
      future: Responsavel.atual(),
      builder: (context, snap) {
        return ValueListenableBuilder<EstadoVigia>(
          valueListenable: Automacao.instancia.vigiaListas.estado,
          builder: (context, vigia, _) => CabecalhoPagina(
            titulo: '${saudacao()}${snap.data == null ? '' : ', ${snap.data!.primeiroNome}'}',
            subtitulo: '${fmtExtenso(DateTime.now())} · '
                '${vigia.ativo ? 'pasta do DinaBox vigiada' : vigia.erro ?? 'pasta das listas parada'}',
            acoes: [
              BuscaEstoque(
                largura: 280,
                onChanged: (_) {},
                onSubmitted: (q) => NavCerebro.ler(context).ir(SecaoCerebro.materiais, buscaMateriais: q),
              ),
              BotaoIcone(
                icone: escuro ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                dica: escuro ? 'Modo claro' : 'Modo escuro',
                onPressed: () async {
                  await UserSession.toggleDarkMode();
                  ThemeNotifier.instance.toggle();
                },
              ),
              StreamBuilder<int>(
                stream: Consultas.instancia.avisosNaoLidos(),
                builder: (context, s) => BotaoIcone(
                  icone: Icons.notifications_none,
                  dica: 'Avisos',
                  contador: s.data ?? 0,
                  onPressed: () => abrirAvisos(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Faixa "Precisa de você": só aparece quando há algo a resolver.
class _PrecisaDeVoce extends StatelessWidget {
  final List<ListaCorte> listas;
  final List<PedidoCompra> rascunhos;
  final List<NotaFiscal> notas;
  const _PrecisaDeVoce({required this.listas, required this.rascunhos, required this.notas});

  @override
  Widget build(BuildContext context) {
    final aConfirmar = listas.where((l) => l.resumo.confirmar > 0).toList();
    final itensConfirmar = aConfirmar.fold<int>(0, (s, l) => s + l.resumo.confirmar);
    final prontos = rascunhos.where((p) => !p.semFornecedor).toList();
    final semFornecedor = rascunhos.where((p) => p.semFornecedor).fold<int>(0, (s, p) => s + p.itens.length);
    final partes = <String>[
      if (itensConfirmar > 0)
        aConfirmar.length == 1
            ? '$itensConfirmar ${itensConfirmar == 1 ? 'item' : 'itens'} da ${aConfirmar.first.titulo} para confirmar'
            : '$itensConfirmar itens para confirmar em ${aConfirmar.length} listas',
      if (prontos.length == 1)
        'pedido da ${prontos.first.fornecedorNome} pronto para enviar (${prontos.first.itens.length} '
            '${prontos.first.itens.length == 1 ? 'item' : 'itens'})',
      if (prontos.length > 1) '${prontos.length} pedidos prontos para enviar',
      if (semFornecedor > 0) '$semFornecedor ${semFornecedor == 1 ? 'item' : 'itens'} sem fornecedor definido',
      for (final n in notas) 'NF ${n.numero} com item para confirmar',
    ];
    final escuro = UserSession.isDarkMode();
    final visivel = partes.isNotEmpty;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: !visivel
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Cascata(
                indice: 1,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: escuro ? dellalioGold.withValues(alpha: 0.45) : petroleoColor.withValues(alpha: 0.25),
                    ),
                    color: escuro ? null : inkSurface,
                    gradient: escuro
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [dellalioGold.withValues(alpha: 0.08), dellalioGold.withValues(alpha: 0.02)],
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      _iconeAlerta(escuro),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Precisa de você', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: panelIvory)),
                            const SizedBox(height: 2),
                            Text(partes.join(' · '), style: TextStyle(color: panelSlate, fontSize: 13.5)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (aConfirmar.isNotEmpty)
                        BotaoEstoque(
                          rotulo: 'Confirmar item',
                          pequeno: true,
                          onPressed: () => NavCerebro.ler(context).abrirLista(aConfirmar.first.id),
                        ),
                      if (notas.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        BotaoEstoque(
                          rotulo: 'Ver nota',
                          pequeno: true,
                          onPressed: () => abrirNota(context, notas.first.id),
                        ),
                      ],
                      if (prontos.isNotEmpty || semFornecedor > 0) ...[
                        const SizedBox(width: 8),
                        BotaoEstoque(
                          rotulo: prontos.length == 1 ? 'Enviar pedido' : 'Ver pedidos',
                          icone: prontos.length == 1 ? Icons.chat_outlined : Icons.shopping_cart_outlined,
                          variante: VarianteBotao.principal,
                          pequeno: true,
                          onPressed: () => prontos.length == 1
                              ? enviarPedido(context, prontos.first)
                              : NavCerebro.ler(context).ir(SecaoCerebro.pedidos),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _iconeAlerta(bool escuro) {
    final icone = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: escuro ? dellalioGold.withValues(alpha: 0.15) : petroleoColor.withValues(alpha: 0.08),
      ),
      child: Icon(Icons.warning_amber_rounded, size: 20, color: escuro ? dellalioGold : petroleoColor),
    );
    return escuro ? AnelPulsante(cor: dellalioGold, child: icone) : icone;
  }
}

class _Kpis extends StatelessWidget {
  final List<MaterialEstoque> materiais;
  final List<ListaCorte> ativas;
  final List<PedidoCompra> pedidos;
  final List<Movimentacao> doMes;
  const _Kpis({required this.materiais, required this.ativas, required this.pedidos, required this.doMes});

  @override
  Widget build(BuildContext context) {
    final nav = NavCerebro.ler(context);
    final valor = materiais.fold<double>(0, (s, m) => s + m.valorEmEstoque);

    // Variação do mês: o que as movimentações do mês mudaram no físico,
    // valorizado pelo custo médio atual.
    final custo = {for (final m in materiais) m.id: m.custoMedio};
    final variacao = doMes.fold<double>(0, (s, m) => s + (m.fisicoDepois - m.fisicoAntes) * (custo[m.materialId] ?? 0));
    final base = valor - variacao;
    final pct = base > 0 ? variacao / base * 100 : null;

    final abaixo = materiais.where((m) => m.abaixoDoMinimo).toList();
    final noPedido = {for (final p in pedidos) for (final i in p.itens) i.materialId};
    final abaixoNoPedido = abaixo.where((m) => noPedido.contains(m.id)).length;

    final aguardando = ativas.where((l) => l.status == StatusLista.aguardandoCompra).toList();
    final itensFaltando = aguardando.fold<int>(0, (s, l) => s + l.resumo.parcial + l.resumo.falta);
    final prontas = ativas.where((l) => l.status == StatusLista.pronta || l.status == StatusLista.reservada).toList();

    final grande = fraunces(46, altura: 1);
    final cards = [
      KpiColuna(
        rotulo: 'Valor em estoque',
        filete: destaqueNeutro,
        valor: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: valor),
          duration: Duration(milliseconds: semAnimacao(context) ? 0 : 700),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            final (numero, sufixo) = valorCompacto(v);
            return Text.rich(
              TextSpan(children: [
                TextSpan(text: 'R\$', style: fraunces(20, cor: panelSlate)),
                TextSpan(text: numero, style: grande),
                if (sufixo != null) TextSpan(text: ' $sufixo', style: fraunces(20, cor: panelSlate)),
              ]),
            );
          },
        ),
        rodapeEsquerda: '${materiais.length} materiais',
        rodapeDireita: pct == null
            ? 'este mês'
            : '${pct >= 0 ? '+' : '−'}${fmtNumero(double.parse(pct.abs().toStringAsFixed(1)))}% no mês',
        corRodapeDireita: pct == null ? null : (pct >= 0 ? estoqueOk : estoqueFalta),
        onTap: () => nav.ir(SecaoCerebro.materiais),
      ),
      KpiColuna(
        rotulo: 'Abaixo do mínimo',
        filete: estoqueAlerta,
        valor: NumeroAnimado(
          valor: abaixo.length.toDouble(),
          formatar: (v) => v.round().toString(),
          estilo: fraunces(46, cor: estoqueAlerta, altura: 1),
        ),
        rodapeEsquerda: 'já no pedido',
        rodapeDireita: '$abaixoNoPedido de ${abaixo.length}',
        onTap: () => nav.ir(SecaoCerebro.materiais, buscaMateriais: '#minimo'),
      ),
      KpiColuna(
        rotulo: 'Aguardando compra',
        filete: destaqueNeutro,
        valor: NumeroAnimado(valor: aguardando.length.toDouble(), formatar: (v) => v.round().toString(), estilo: grande),
        rodapeEsquerda: 'listas de corte',
        rodapeDireita: '$itensFaltando ${itensFaltando == 1 ? 'item' : 'itens'}',
        onTap: () => nav.ir(SecaoCerebro.listas),
      ),
      KpiColuna(
        rotulo: 'Prontas para cortar',
        filete: estoqueOk,
        valor: NumeroAnimado(valor: prontas.length.toDouble(), formatar: (v) => v.round().toString(), estilo: grande),
        rodapeEsquerda: 'tudo separado',
        rodapeDireita: 'liberar',
        corRodapeDireita: estoqueOk,
        onTap: () => prontas.isEmpty ? nav.ir(SecaoCerebro.listas) : nav.abrirLista(prontas.first.id),
      ),
    ];
    return Row(
      children: [
        for (final (i, k) in cards.indexed) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: Cascata(indice: i, child: k)),
        ],
      ],
    );
  }
}

/// Pílula da lista: confirmar > status.
Widget pilulaLista(ListaCorte l) {
  if (l.resumo.confirmar > 0 && l.status.ativa) {
    return PilulaStatus(rotulo: '${l.resumo.confirmar} confirmar', cor: estoqueOuro);
  }
  return PilulaStatus(rotulo: l.status.rotulo, cor: corStatusLista(l.status));
}

class _ListasRecentes extends StatelessWidget {
  final List<ListaCorte> listas;
  const _ListasRecentes(this.listas);

  @override
  Widget build(BuildContext context) {
    final nav = NavCerebro.ler(context);
    return PainelEstoque(
      titulo: 'Listas recentes',
      link: 'Ver todas',
      onLink: () => nav.ir(SecaoCerebro.listas),
      child: listas.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Nenhuma lista ainda. Salve a lista do DinaBox na pasta vigiada ou arraste o arquivo para esta janela.',
                style: TextStyle(color: panelSlate),
              ),
            )
          : Column(
              children: [
                for (final (i, l) in listas.indexed)
                  Cascata(
                    indice: i,
                    child: InkWell(
                      onTap: () => nav.abrirLista(l.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: i == 0 ? Colors.transparent : hairlineNavy)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 14,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.titulo, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: panelIvory)),
                                  Text(subtituloLista(l), style: TextStyle(color: panelSlateDim, fontSize: 12.5)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 10,
                              child: BarraSituacao(
                                resumo: l.resumo,
                                neutra: l.status == StatusLista.cortada || l.status == StatusLista.cancelada,
                              ),
                            ),
                            const SizedBox(width: 14),
                            pilulaLista(l),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _UltimasMovs extends StatelessWidget {
  final List<Movimentacao> movs;
  const _UltimasMovs(this.movs);

  @override
  Widget build(BuildContext context) {
    final nav = NavCerebro.ler(context);
    return PainelEstoque(
      titulo: 'Últimas movimentações',
      link: 'Livro-razão',
      onLink: () => nav.ir(SecaoCerebro.movimentacoes),
      child: movs.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Sem movimentações ainda.', style: TextStyle(color: panelSlate)),
            )
          : Column(
              children: [
                for (final (i, m) in movs.indexed)
                  Cascata(
                    indice: i,
                    child: InkWell(
                      onTap: () => nav.abrirMaterial(m.materialId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: i == 0 ? Colors.transparent : hairlineNavy)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 96,
                              child: Text(m.tipo.rotulo.split(' ').first, style: TextStyle(color: corTipoMov(m.tipo), fontSize: 14)),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.materialNome, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: panelIvory)),
                                  Text(resumoMov(m), overflow: TextOverflow.ellipsis, style: TextStyle(color: panelSlateDim, fontSize: 12.5)),
                                ],
                              ),
                            ),
                            Text(
                              qtdMov(m),
                              style: TextStyle(fontWeight: FontWeight.w600, color: panelIvory, fontFeatures: numerosTabulares),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Usado pela lista de listas também.
String quantidadeDe(double v, UnidadeEstoque? u) => u == null ? fmtNumero(v) : fmtQtd(v, u);
