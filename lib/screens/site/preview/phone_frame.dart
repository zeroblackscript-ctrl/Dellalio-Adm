import 'package:flutter/material.dart';

/// Moldura de celular que envolve o preview ao vivo de uma seção da vitrine
/// do app Dellalio Clientes — a tela dentro dela é sempre 390×844 (proporção
/// de um smartphone comum) e se ajusta ao espaço disponível.
class PhoneFrame extends StatelessWidget {
  final Widget child;
  const PhoneFrame({super.key, required this.child});

  static const double _screenWidth = 390;
  static const double _screenHeight = 844;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const bezel = 14.0;
        final maxW = constraints.maxWidth - bezel * 2;
        final maxH = constraints.maxHeight - bezel * 2;
        final scaleW = maxW / _screenWidth;
        final scaleH = maxH / _screenHeight;
        final scale = (scaleW < scaleH ? scaleW : scaleH).clamp(0.05, 10.0);

        return Center(
          child: Container(
            width: _screenWidth * scale + bezel * 2,
            height: _screenHeight * scale + bezel * 2,
            padding: const EdgeInsets.all(bezel),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(46),
              border: Border.all(color: const Color(0xFF2A2A2A), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: SizedBox(
                    width: _screenWidth * scale,
                    height: _screenHeight * scale,
                    // FittedBox deixa o filho se layoutar no tamanho real
                    // (390×844) antes de encolher visualmente — um
                    // Transform.scale aninhado em SizedBoxes com constraints
                    // apertadas força o layout a já acontecer no tamanho
                    // pequeno (conteúdo acha que tem poucos pixels de
                    // largura) e ainda escala de novo por cima, causando
                    // overflow e a tela não preencher o aparelho.
                    child: FittedBox(
                      fit: BoxFit.fill,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: _screenWidth,
                        height: _screenHeight,
                        // Sem isso, MediaQuery dentro do celular herdaria o
                        // tamanho da janela real do admin (bem maior que um
                        // celular) — qualquer widget que dependa dela pra
                        // calcular layout se comportaria errado.
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            size: const Size(_screenWidth, _screenHeight),
                            padding: EdgeInsets.zero,
                            viewPadding: EdgeInsets.zero,
                            viewInsets: EdgeInsets.zero,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
                // Notch/câmera — só decorativo.
                Positioned(
                  top: 0,
                  child: Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 120 * scale,
                    height: 22 * scale,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
