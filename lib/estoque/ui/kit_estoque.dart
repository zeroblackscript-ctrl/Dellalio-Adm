import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../models/models.dart';

/// Peças visuais do estoque (Cérebro), em cima do `dellalio_kit.dart` e dos
/// tokens do `theme.dart`. Toda animação respeita
/// `MediaQuery.disableAnimations`.

const List<FontFeature> numerosTabulares = [FontFeature.tabularFigures()];

/// Desligado só na prévia das telas (testes), onde a Fraunces é carregada
/// de arquivo local em vez de baixada.
bool usarGoogleFonts = true;

/// Fraunces pra títulos e números de destaque.
TextStyle fraunces(
  double tamanho, {
  Color? cor,
  FontWeight peso = FontWeight.w500,
  double? altura,
}) {
  final estilo = TextStyle(
    fontSize: tamanho,
    fontWeight: peso,
    color: cor ?? dellalioTitle,
    height: altura,
    letterSpacing: -0.01 * tamanho,
    fontFeatures: numerosTabulares,
  );
  return usarGoogleFonts
      ? GoogleFonts.fraunces(textStyle: estilo)
      : estilo.copyWith(fontFamily: 'Fraunces');
}

/// Texto de UI herdando a fonte do tema (Inter). Usar onde o widget troca o
/// estilo inteiro em vez de mesclar (ex.: `DropdownButton.style`).
TextStyle textoUi(BuildContext context, {double tamanho = 13.5, Color? cor}) =>
    (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
      fontSize: tamanho,
      color: cor ?? panelIvory,
    );

bool semAnimacao(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Cor semântica de cada situação de item de lista.
Color corSituacao(SituacaoItem s) => switch (s) {
  SituacaoItem.ok => estoqueOk,
  SituacaoItem.parcial => estoqueAlerta,
  SituacaoItem.falta => estoqueFalta,
  SituacaoItem.confirmar => estoqueOuro,
};

Color corStatusLista(StatusLista s) => switch (s) {
  StatusLista.pronta || StatusLista.reservada => estoqueOk,
  StatusLista.aguardandoCompra => estoqueAlerta,
  StatusLista.lida => estoqueOuro,
  StatusLista.cortada || StatusLista.cancelada => estoqueNeutro,
};

Color corTipoMov(TipoMovimentacao t) => switch (t) {
  TipoMovimentacao.entrada => estoqueOk,
  TipoMovimentacao.saida => estoqueFalta,
  TipoMovimentacao.reserva => estoqueAlerta,
  TipoMovimentacao.liberacaoReserva ||
  TipoMovimentacao.ajuste ||
  TipoMovimentacao.perda => estoqueNeutro,
};

// ------------------------------------------------------------- animações

/// Entrada em cascata: sobe 14 px e aparece em 550 ms (easeOutCubic), com
/// 60 ms entre itens — o padrão do kit.
class Cascata extends StatelessWidget {
  final int indice;
  final Widget child;
  const Cascata({super.key, required this.indice, required this.child});

  @override
  Widget build(BuildContext context) {
    if (semAnimacao(context)) return child;
    final atraso = (60 * indice.clamp(0, 14)).ms;
    return child
        .animate(delay: atraso)
        .fadeIn(duration: 550.ms, curve: Curves.easeOutCubic)
        .moveY(begin: 14, end: 0, duration: 550.ms, curve: Curves.easeOutCubic);
  }
}

/// Número que conta do valor anterior ao novo em ~700 ms quando o
/// `StreamBuilder` traz dado novo.
class NumeroAnimado extends StatelessWidget {
  final double valor;
  final String Function(double v) formatar;
  final TextStyle estilo;
  const NumeroAnimado({
    super.key,
    required this.valor,
    required this.formatar,
    required this.estilo,
  });

  @override
  Widget build(BuildContext context) {
    if (semAnimacao(context)) return Text(formatar(valor), style: estilo);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valor),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(formatar(v), style: estilo),
    );
  }
}

/// Barra de situação proporcional ao resumo (verde/âmbar/vermelho/dourado).
/// Cresce da esquerda pra direita em 900 ms e reanima quando o resumo muda.
class BarraSituacao extends StatelessWidget {
  final ResumoLista resumo;
  final bool neutra;
  final double altura;
  const BarraSituacao({
    super.key,
    required this.resumo,
    this.neutra = false,
    this.altura = 8,
  });

  @override
  Widget build(BuildContext context) {
    final partes = neutra
        ? [(1, estoqueNeutro)]
        : [
            (resumo.ok, estoqueOk),
            (resumo.parcial, estoqueAlerta),
            (resumo.falta, estoqueFalta),
            (resumo.confirmar, estoqueOuro),
          ].where((p) => p.$1 > 0).toList();
    final barra = Row(
      children: [
        for (final p in partes)
          Expanded(
            flex: p.$1,
            child: Container(color: p.$2),
          ),
      ],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: altura,
        color: inkSurface3,
        child: semAnimacao(context)
            ? barra
            : TweenAnimationBuilder<double>(
                key: ValueKey(Object.hash(resumo, neutra)),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                child: barra,
                builder: (context, t, child) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: t,
                  child: child,
                ),
              ),
      ),
    );
  }
}

/// Anel dourado que expande e some a cada 2,2 s em volta de um ícone.
class AnelPulsante extends StatelessWidget {
  final Widget child;
  final Color cor;
  final double raio;
  const AnelPulsante({
    super.key,
    required this.child,
    required this.cor,
    this.raio = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (semAnimacao(context)) return child;
    return child
        .animate(onPlay: (c) => c.repeat())
        .custom(
          duration: 2200.ms,
          builder: (context, v, child) {
            // 0→0.5 expande, 0.5→1 descansa (como o keyframe da referência).
            final t = v < 0.5 ? v * 2 : 1.0;
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(raio),
                boxShadow: [
                  BoxShadow(
                    color: cor.withValues(alpha: 0.45 * (1 - t)),
                    spreadRadius: 8 * t,
                  ),
                ],
              ),
              child: child,
            );
          },
        );
  }
}

/// Fundo que pisca dourado uma vez quando [chave] muda (item que mudou de
/// situação ao vivo).
class PiscaAoMudar extends StatefulWidget {
  final Object? chave;
  final Widget child;
  const PiscaAoMudar({super.key, required this.chave, required this.child});

  @override
  State<PiscaAoMudar> createState() => _PiscaAoMudarState();
}

class _PiscaAoMudarState extends State<PiscaAoMudar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );

  @override
  void didUpdateWidget(PiscaAoMudar old) {
    super.didUpdateWidget(old);
    if (old.chave != widget.chave && !semAnimacao(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: dellalioGold.withValues(alpha: 0.16 * (1 - _c.value)),
        ),
        child: child,
      ),
    );
  }
}

// --------------------------------------------------------------- peças

/// Pílula com fundo translúcido da própria cor. Ao trocar de rótulo faz
/// cross-fade com uma leve escala (1.0 → 1.08 → 1.0).
class PilulaStatus extends StatelessWidget {
  final String rotulo;
  final Color cor;
  final bool pequena;
  const PilulaStatus({
    super.key,
    required this.rotulo,
    required this.cor,
    this.pequena = false,
  });

  @override
  Widget build(BuildContext context) {
    final pilula = Container(
      key: ValueKey('$rotulo${cor.toARGB32()}'),
      padding: EdgeInsets.symmetric(
        horizontal: pequena ? 7 : 10,
        vertical: pequena ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        rotulo,
        style: TextStyle(
          color: cor,
          fontSize: pequena ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (semAnimacao(context)) return pilula;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      layoutBuilder: (atual, anteriores) => Stack(
        alignment: Alignment.centerLeft,
        children: [...anteriores, ?atual],
      ),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: TweenSequence([
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 1),
            TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 1),
          ]).animate(anim),
          child: child,
        ),
      ),
      child: pilula,
    );
  }
}

/// Selo "NOVO" de material criado automaticamente.
class SeloNovo extends StatelessWidget {
  const SeloNovo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: estoqueOuro.withValues(alpha: 0.5)),
      ),
      child: Text(
        'NOVO',
        style: TextStyle(
          color: estoqueOuro,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Rótulo em caixa alta espaçada (KPIs, cabeçalho de tabela).
class RotuloCaixaAlta extends StatelessWidget {
  final String texto;
  final Color? cor;
  const RotuloCaixaAlta(this.texto, {super.key, this.cor});

  @override
  Widget build(BuildContext context) => Text(
    texto.toUpperCase(),
    style: TextStyle(
      fontSize: 11.5,
      letterSpacing: 1.6,
      fontWeight: FontWeight.w600,
      color: cor ?? panelSlate,
    ),
  );
}

enum VarianteBotao { principal, secundario, fantasma, whatsapp }

/// Botão do estoque. `principal` é dourado no escuro e navy no claro.
class BotaoEstoque extends StatefulWidget {
  final String rotulo;
  final IconData? icone;
  final VoidCallback? onPressed;
  final VarianteBotao variante;
  final bool pequeno;
  final bool carregando;
  final bool larguraTotal;

  /// Ação disponível mas fora de hora (ex.: cortar lista que ainda espera
  /// compra): aparece apagada, continua clicável.
  final bool esmaecido;

  const BotaoEstoque({
    super.key,
    required this.rotulo,
    this.icone,
    required this.onPressed,
    this.variante = VarianteBotao.secundario,
    this.pequeno = false,
    this.carregando = false,
    this.larguraTotal = false,
    this.esmaecido = false,
  });

  @override
  State<BotaoEstoque> createState() => _BotaoEstoqueState();
}

class _BotaoEstoqueState extends State<BotaoEstoque> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ativo = widget.onPressed != null && !widget.carregando;
    final (fundo, texto, borda) = switch (widget.variante) {
      VarianteBotao.principal => (
        acaoPrincipal,
        acaoPrincipalTexto,
        acaoPrincipal,
      ),
      VarianteBotao.whatsapp => (whatsappVerde, Colors.white, whatsappVerde),
      VarianteBotao.secundario => (inkSurface2, panelIvory, hairlineNavy),
      VarianteBotao.fantasma => (Colors.transparent, panelIvory, hairlineNavy),
    };
    final altura = widget.pequeno ? 32.0 : 40.0;
    return Opacity(
      opacity: ativo && !widget.esmaecido ? 1 : 0.45,
      child: MouseRegion(
        cursor: ativo ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: ativo ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: altura,
            width: widget.larguraTotal ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: widget.pequeno ? 12 : 16),
            decoration: BoxDecoration(
              color: _hover && ativo
                  ? Color.alphaBlend(
                      (widget.variante == VarianteBotao.principal ||
                                  widget.variante == VarianteBotao.whatsapp
                              ? Colors.white
                              : estoqueOuro)
                          .withValues(alpha: 0.10),
                      fundo,
                    )
                  : fundo,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    _hover &&
                        ativo &&
                        (widget.variante == VarianteBotao.secundario ||
                            widget.variante == VarianteBotao.fantasma)
                    ? estoqueOuro
                    : borda,
              ),
            ),
            child: Row(
              mainAxisSize: widget.larguraTotal
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.carregando)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: texto,
                    ),
                  )
                else if (widget.icone != null)
                  Icon(widget.icone, size: 16, color: texto),
                if (widget.carregando || widget.icone != null)
                  const SizedBox(width: 8),
                Text(
                  widget.rotulo,
                  style: TextStyle(
                    color: texto,
                    fontSize: widget.pequeno ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão quadrado só de ícone (tema, sino), com contador opcional.
class BotaoIcone extends StatelessWidget {
  final IconData icone;
  final VoidCallback onPressed;
  final String? dica;
  final int contador;
  const BotaoIcone({
    super.key,
    required this.icone,
    required this.onPressed,
    this.dica,
    this.contador = 0,
  });

  @override
  Widget build(BuildContext context) {
    final botao = Material(
      color: inkSurface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hairlineNavy),
          ),
          child: Icon(icone, size: 18, color: panelSlate),
        ),
      ),
    );
    return Tooltip(
      message: dica ?? '',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          botao,
          if (contador > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: dellalioGold,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$contador',
                  style: const TextStyle(
                    color: Color(0xFF1B1503),
                    fontSize: 10.5,
                    height: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chip de filtro (ativo = dourado cheio).
class ChipFiltro extends StatelessWidget {
  final String rotulo;
  final bool ativo;
  final VoidCallback onTap;
  const ChipFiltro({
    super.key,
    required this.rotulo,
    required this.ativo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ativo ? acaoPrincipal : inkSurface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: ativo ? acaoPrincipal : hairlineNavy),
          ),
          child: Text(
            rotulo,
            style: TextStyle(
              fontSize: 13,
              fontWeight: ativo ? FontWeight.w600 : FontWeight.w400,
              color: ativo ? acaoPrincipalTexto : panelSlate,
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de busca do estoque (aceita controller pra vir preenchido).
class BuscaEstoque extends StatelessWidget {
  final String dica;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final double? largura;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  const BuscaEstoque({
    super.key,
    this.dica = 'Buscar material',
    required this.onChanged,
    this.controller,
    this.largura,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: largura,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: inkSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hairlineNavy),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: panelSlateDim),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: TextStyle(color: panelIvory, fontSize: 14),
              cursorColor: estoqueOuro,
              decoration: InputDecoration(
                hintText: dica,
                hintStyle: TextStyle(color: panelSlateDim, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Painel padrão (cartão um tom acima do fundo, borda fina, título Fraunces).
class PainelEstoque extends StatelessWidget {
  final String? titulo;
  final String? link;
  final VoidCallback? onLink;
  final Widget child;
  final EdgeInsets padding;
  final bool tracejado;
  const PainelEstoque({
    super.key,
    this.titulo,
    this.link,
    this.onLink,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
    this.tracejado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: inkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hairlineNavy),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (titulo != null) ...[
            Row(
              children: [
                Expanded(child: Text(titulo!, style: fraunces(20))),
                if (link != null)
                  TextButton(
                    onPressed: onLink,
                    style: TextButton.styleFrom(
                      foregroundColor: estoqueOuro,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                    ),
                    child: Text(
                      link!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// KPI alto e estreito, estilo coluna de jornal: filete superior colorido,
/// rótulo em caixa alta, número grande em Fraunces e rodapé com divisória.
class KpiColuna extends StatelessWidget {
  final String rotulo;
  final Widget valor;
  final Color filete;
  final String rodapeEsquerda;
  final String rodapeDireita;
  final Color? corRodapeDireita;
  final VoidCallback? onTap;

  const KpiColuna({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.filete,
    required this.rodapeEsquerda,
    required this.rodapeDireita,
    this.corRodapeDireita,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        // Borda com cores diferentes não aceita raio no Flutter: o filete é
        // uma faixa própria dentro do cartão recortado.
        child: Container(
          height: 178,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: inkSurface,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(14),
            ),
            border: Border.all(color: hairlineNavy),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 3, color: filete),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RotuloCaixaAlta(rotulo),
                      valor,
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: hairlineNavy)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                rodapeEsquerda,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: panelSlateDim,
                                ),
                              ),
                            ),
                            Text(
                              rodapeDireita,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: corRodapeDireita ?? panelSlateDim,
                                fontFeatures: numerosTabulares,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stepper compacto (− 3 +) dos itens de pedido.
class StepperCompacto extends StatelessWidget {
  final double valor;
  final ValueChanged<double> onChanged;
  final double passo;
  const StepperCompacto({
    super.key,
    required this.valor,
    required this.onChanged,
    this.passo = 1,
  });

  @override
  Widget build(BuildContext context) {
    Widget botao(String s, VoidCallback f) => InkWell(
      onTap: f,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: Text(s, style: TextStyle(color: panelSlate, fontSize: 14)),
      ),
    );
    final texto = valor == valor.roundToDouble()
        ? valor.toInt().toString()
        : valor.toStringAsFixed(1).replaceAll('.', ',');
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: hairlineNavy),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          botao(
            '−',
            () => onChanged((valor - passo).clamp(0, double.infinity)),
          ),
          Container(
            color: inkSurface2,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Text(
              texto,
              style: TextStyle(
                color: panelIvory,
                fontWeight: FontWeight.w600,
                fontFeatures: numerosTabulares,
              ),
            ),
          ),
          botao('+', () => onChanged(valor + passo)),
        ],
      ),
    );
  }
}

/// Borda tracejada (item a confirmar, card "Sem fornecedor", área de soltar).
class BordaTracejada extends StatelessWidget {
  final Widget child;
  final Color cor;
  final double raio;
  final Color? fundo;
  const BordaTracejada({
    super.key,
    required this.child,
    required this.cor,
    this.raio = 12,
    this.fundo,
  });

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _Tracejado(cor, raio, fundo), child: child);
}

class _Tracejado extends CustomPainter {
  final Color cor;
  final double raio;
  final Color? fundo;
  _Tracejado(this.cor, this.raio, this.fundo);

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(raio),
    );
    if (fundo != null) canvas.drawRRect(rr, Paint()..color = fundo!);
    final p = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in (Path()..addRRect(rr.deflate(0.5))).computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), p);
      }
    }
  }

  @override
  bool shouldRepaint(_Tracejado old) => old.cor != cor || old.fundo != fundo;
}

/// Título de página (Fraunces 34) + subtítulo + ferramentas à direita.
class CabecalhoPagina extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final List<Widget> acoes;
  final Widget? antes;
  const CabecalhoPagina({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.acoes = const [],
    this.antes,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (antes != null) ...[antes!, const SizedBox(width: 14)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: fraunces(34),
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitulo!,
                  style: TextStyle(color: panelSlate, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        for (final (i, a) in acoes.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          a,
        ],
      ],
    );
  }
}

/// Item da linha do tempo do histórico: bolinha colorida, "Tipo · para
/// quem", quantidade com sinal e "origem · responsável · data".
class ItemLinhaTempo extends StatelessWidget {
  final Color cor;
  final String titulo;
  final String quantidade;
  final String detalhe;
  final bool ultimo;
  final bool tituloColorido;
  const ItemLinhaTempo({
    super.key,
    required this.cor,
    required this.titulo,
    required this.quantidade,
    required this.detalhe,
    this.ultimo = false,
    this.tituloColorido = true,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!ultimo)
                  Positioned(
                    top: 14,
                    bottom: 0,
                    child: Container(width: 2, color: hairlineNavy),
                  ),
                Positioned(
                  top: 9,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: cor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: inkSurface, spreadRadius: 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          titulo,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: tituloColorido ? cor : panelIvory,
                          ),
                        ),
                      ),
                      Text(
                        quantidade,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: panelIvory,
                          fontFeatures: numerosTabulares,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalhe,
                    style: TextStyle(color: panelSlateDim, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vários streams ao vivo de uma vez. [builder] recebe o último valor de
/// cada um (null até chegar) e só é chamado depois que todos chegaram, a
/// não ser que [parcial] seja true.
class Vivos extends StatefulWidget {
  final List<Stream<Object?>> streams;
  final Widget Function(BuildContext context, List<Object?> valores) builder;
  final bool parcial;
  const Vivos({
    super.key,
    required this.streams,
    required this.builder,
    this.parcial = false,
  });

  @override
  State<Vivos> createState() => _VivosState();
}

class _VivosState extends State<Vivos> {
  late List<Object?> _valores;
  late List<bool> _chegou;
  final List<StreamSubscription<Object?>> _subs = [];
  Object? _erro;

  @override
  void initState() {
    super.initState();
    _assinar();
  }

  void _assinar() {
    _valores = List.filled(widget.streams.length, null);
    _chegou = List.filled(widget.streams.length, false);
    for (final (i, s) in widget.streams.indexed) {
      _subs.add(
        s.listen(
          (v) {
            if (!mounted) return;
            setState(() {
              _valores[i] = v;
              _chegou[i] = true;
            });
          },
          onError: (Object e) {
            if (mounted) setState(() => _erro = e);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_erro != null) return ErroConsulta(_erro!);
    if (!widget.parcial && _chegou.contains(false)) return const Carregando();
    return widget.builder(context, _valores);
  }
}

/// Carregando padrão das telas.
class Carregando extends StatelessWidget {
  const Carregando({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Center(
      child: CircularProgressIndicator(color: estoqueOuro, strokeWidth: 2),
    ),
  );
}

/// Erro de consulta (índice faltando, sem rede): mostra, não derruba.
class ErroConsulta extends StatelessWidget {
  final Object erro;
  const ErroConsulta(this.erro, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Text(
      'Não consegui carregar: $erro',
      style: TextStyle(color: estoqueFalta, fontSize: 13),
    ),
  );
}

/// Diálogo de confirmação no visual do estoque. Devolve `true` no Sim.
Future<bool?> perguntar(
  BuildContext context, {
  required String titulo,
  required String texto,
  String sim = 'Confirmar',
  String nao = 'Cancelar',
  bool perigo = false,
}) => showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    backgroundColor: inkSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: hairlineNavy),
    ),
    title: Text(titulo, style: fraunces(22)),
    content: Text(texto, style: TextStyle(color: panelSlate, height: 1.4)),
    actions: [
      BotaoEstoque(
        rotulo: nao,
        variante: VarianteBotao.fantasma,
        onPressed: () => Navigator.pop(ctx, false),
      ),
      BotaoEstoque(
        rotulo: sim,
        variante: VarianteBotao.principal,
        icone: perigo ? Icons.warning_amber_rounded : Icons.check,
        onPressed: () => Navigator.pop(ctx, true),
      ),
    ],
  ),
);

/// Mensagem curta no rodapé da janela.
void avisar(BuildContext context, String texto, {bool erro = false}) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 460,
        backgroundColor: erro ? estoqueFalta : inkSurface3,
        content: Text(
          texto,
          style: TextStyle(color: erro ? Colors.white : panelIvory),
        ),
      ),
    );
}
