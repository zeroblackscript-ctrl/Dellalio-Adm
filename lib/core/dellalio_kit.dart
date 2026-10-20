import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'theme.dart';

/// Kit de widgets do redesign do Cérebro. Centraliza os elementos que se
/// repetem em várias telas (busca, botões, pills, cards) pra manter tudo
/// consistente sem redefinir cada peça em cada arquivo.

/// Título de página no padrão Fraunces + fade/rise na entrada.
class DellalioPageHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const DellalioPageHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.w500,
              fontSize: 27,
              color: dellalioTitle,
            ),
          ),
        ),
        ?trailing,
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }
}

/// Cabeçalho de sub-tela: seta de voltar + título Fraunces + ação opcional.
/// Usar em cadastro/edição/detalhe/chat no lugar do `AppBar`.
class DellalioSubHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const DellalioSubHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Row(
        children: [
          DellalioIconGhostButton(
            icon: Icons.arrow_back,
            tooltip: 'Voltar',
            size: 34,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w500,
                fontSize: 22,
                color: dellalioTitle,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }
}

/// Cabeçalho leve pra conteúdo trocado in-place (sem navegar de tela) —
/// seta de voltar opcional + título + ação de salvar. Mais enxuto que
/// [DellalioSubHeader], pensado pra painéis estreitos (ex.: coluna de
/// edição ao lado de um preview fixo).
class EditorInlineHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final bool saving;
  final VoidCallback onSave;
  const EditorInlineHeader({
    super.key,
    required this.title,
    this.onBack,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          DellalioIconGhostButton(
            icon: Icons.arrow_back,
            tooltip: 'Voltar',
            size: 30,
            onPressed: onBack!,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: dellalioTitle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: dellalioGold,
                ),
              )
            : DellalioGhostButton(
                label: "Salvar",
                icon: Icons.save_outlined,
                onPressed: onSave,
              ),
      ],
    );
  }
}

/// Campo de busca padrão — fundo charcoal, foco com contorno azul sutil.
class DellalioSearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const DellalioSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<DellalioSearchField> createState() => _DellalioSearchFieldState();
}

class _DellalioSearchFieldState extends State<DellalioSearchField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (has) => setState(() => _focused = has),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: inkSurface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _focused ? hairlineNavy : hairline),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: panelSlateDim),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                onChanged: widget.onChanged,
                style: TextStyle(color: panelIvory, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(color: panelSlateDim, fontSize: 13.5),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de formulário padrão do redesign — fundo charcoal, rótulo slate e
/// foco com contorno azul sutil. Substitui `TextFormField`/`TextField` em todo
/// formulário do app, mantendo exatamente os mesmos parâmetros de validação,
/// máscara, teclado, etc.
class DellalioFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscure;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool readOnly;
  final FocusNode? focusNode;

  const DellalioFormField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.validator,
    this.inputFormatters,
    this.keyboardType,
    this.maxLines = 1,
    this.obscure = false,
    this.suffixIcon,
    this.onChanged,
    this.onFieldSubmitted,
    this.readOnly = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      maxLines: maxLines,
      obscureText: obscure,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      readOnly: readOnly,
      focusNode: focusNode,
      style: TextStyle(color: panelIvory, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: panelSlate, fontSize: 13),
        hintStyle: TextStyle(color: panelSlateDim),
        filled: true,
        fillColor: inkSurface,
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: panelSlate)
            : null,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: hairlineNavy, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: panelRust),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: panelRust, width: 1.4),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: hairline),
        ),
      ),
    );
  }
}

/// Botão de ação principal — fundo dourado sólido. Usar no máximo um por
/// tela (a régua do sistema já reserva o dourado cheio pra ação principal).
class DellalioGoldButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool fullWidth;
  const DellalioGoldButton({
    super.key,
    required this.label,
    this.icon = Icons.add,
    required this.onPressed,
    this.fullWidth = false,
  });

  @override
  State<DellalioGoldButton> createState() => _DellalioGoldButtonState();
}

class _DellalioGoldButtonState extends State<DellalioGoldButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: _hover ? dellalioGoldSoft : dellalioGold,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: widget.fullWidth
                ? MainAxisSize.max
                : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 16, color: inkPageBg),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: inkPageBg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão de ação secundária — contorno neutro que acende dourado no hover.
class DellalioGhostButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool fullWidth;
  const DellalioGhostButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.fullWidth = false,
  });

  @override
  State<DellalioGhostButton> createState() => _DellalioGhostButtonState();
}

class _DellalioGhostButtonState extends State<DellalioGhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _hover ? dellalioGold : hairline),
          ),
          child: Row(
            mainAxisSize: widget.fullWidth
                ? MainAxisSize.max
                : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 15,
                  color: _hover ? dellalioGoldSoft : panelIvory,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: _hover ? dellalioGoldSoft : panelIvory,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão circular fantasma (ícone só) — histórico, atualizar, etc.
class DellalioIconGhostButton extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;
  final double size;
  const DellalioIconGhostButton({
    super.key,
    required this.icon,
    this.tooltip,
    required this.onPressed,
    this.size = 38,
  });

  @override
  State<DellalioIconGhostButton> createState() =>
      _DellalioIconGhostButtonState();
}

class _DellalioIconGhostButtonState extends State<DellalioIconGhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _hover ? dellalioGold : hairline),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: widget.size * 0.44,
            color: _hover ? dellalioGoldSoft : panelSlate,
          ),
        ),
      ),
    );
    return widget.tooltip != null
        ? Tooltip(message: widget.tooltip!, child: button)
        : button;
  }
}

/// Pill com pontinho colorido — status, categoria, etc. `neutral: true` pra
/// estados tipo "sem projetos" (sem cor de destaque).
class DellalioStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool neutral;
  const DellalioStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.neutral = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: neutral ? Colors.transparent : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: neutral ? hairline : color.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: neutral ? panelSlateDim : color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.5,
              color: neutral ? panelSlate : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge retangular pequeno — usado em cards de tarefas/lembretes.
/// Pin de nível/prioridade — encaixa no canto superior direito de um card
/// (sobre a barra de destaque), mostrando só a cor pra não poluir; o rótulo
/// aparece via Tooltip no hover. Ex: urgência de tarefa, prioridade de
/// lembrete.
class DellalioLevelPin extends StatelessWidget {
  final Color color;
  final String label;
  const DellalioLevelPin({
    super.key,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(7),
            bottomLeft: Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.push_pin, size: 11, color: Colors.white),
      ),
    );
  }
}

class DellalioBadge extends StatelessWidget {
  final String label;
  final Color color;
  const DellalioBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Avatar circular com aro colorido e, opcionalmente, um pulso sutil (usar
/// pra itens críticos/urgentes). Mostra a imagem se `imageUrl` vier
/// preenchida, senão a inicial da marca.
class DellalioAvatarRing extends StatelessWidget {
  final String imageUrl;
  final Color ring;
  final bool pulse;
  final double size;
  final ImageProvider Function(String url)? imageProviderBuilder;

  const DellalioAvatarRing({
    super.key,
    required this.imageUrl,
    required this.ring,
    this.pulse = false,
    this.size = 76,
    this.imageProviderBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: inkPageBg,
        border: Border.all(color: ring, width: 1.6),
        image: imageUrl.isNotEmpty
            ? DecorationImage(
                image: imageProviderBuilder != null
                    ? imageProviderBuilder!(imageUrl)
                    : NetworkImage(imageUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: imageUrl.isEmpty
          ? Text(
              'D',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: size * 0.29,
                color: dellalioGoldSoft,
              ),
            )
          : null,
    );

    if (!pulse) return avatar;

    return Stack(
      alignment: Alignment.center,
      children: [
        avatar,
        IgnorePointer(
          child:
              Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ring),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .custom(
                    duration: 2200.ms,
                    builder: (context, value, child) => Opacity(
                      opacity: (1 - value) * 0.55,
                      child: Transform.scale(
                        scale: 1 + value * 0.22,
                        child: child,
                      ),
                    ),
                  ),
        ),
      ],
    );
  }
}

/// Estado vazio padrão — ícone + título + legenda, centralizado.
class DellalioEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const DellalioEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: panelSlateDim),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: panelSlate, fontSize: 14)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(color: panelSlateDim, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card genérico com hover-lift e entrada em cascata — corpo em charcoal,
/// borda superior colorida opcional (`accent`).
class DellalioCard extends StatefulWidget {
  final Widget child;
  final Color? accent;
  final int delayIndex;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const DellalioCard({
    super.key,
    required this.child,
    this.accent,
    this.delayIndex = 0,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  State<DellalioCard> createState() => _DellalioCardState();
}

class _DellalioCardState extends State<DellalioCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    Widget content = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _hover ? inkSurfaceHover : inkSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: hairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.accent != null)
                Container(height: 3, color: widget.accent),
              Padding(padding: widget.padding, child: widget.child),
            ],
          ),
        ),
      ),
    );

    return content
        .animate(delay: (50 * widget.delayIndex).ms)
        .fadeIn(duration: 420.ms, curve: Curves.easeOut)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOut);
  }
}
