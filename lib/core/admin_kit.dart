import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'theme.dart';

/// Paleta clara do painel administrativo — fiel ao preview aprovado.
/// Independe do toggle claro/escuro: o painel usa sempre este visual
/// (sidebar navy + conteúdo cream/paper), igual ao mockup.
const Color adminCream = Color(0xFFF6F3EC);
const Color adminPaper = Color(0xFFFBFAF7);
const Color adminInk = Color(0xFF1C1F26);
const Color adminInkSoft = Color(0xFF5C6470);
final Color adminLine = petroleoColor.withValues(alpha: 0.08);

/// Painel com título + linha de apoio (mesmo padrão do card "Documentos do
/// projeto" no preview): fundo paper, borda fina, cantos de 14.
class AdminPanel extends StatelessWidget {
  final String title;
  final String? hint;
  final Widget child;
  final Widget? trailing;

  const AdminPanel({
    super.key,
    required this.title,
    this.hint,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      decoration: BoxDecoration(
        color: adminPaper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: adminLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: adminInk,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: const TextStyle(fontSize: 12, color: adminInkSoft)),
          ],
          const SizedBox(height: 12),
          child,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Linha dentro de um AdminPanel (mesmo padrão do "doc-row" do preview):
/// ícone à esquerda num chip, título + subtítulo, ação/badge à direita.
class AdminRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const AdminRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: adminInk),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!,
                              style: const TextStyle(
                                  fontSize: 11.5, color: adminInkSoft),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
        if (showDivider) Divider(color: adminLine, height: 1),
      ],
    );
  }
}

/// Cartão de KPI, no padrão "hero" (navy, maior) ou "light" (paper, com
/// badge opcional), igual ao preview.
class AdminKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final bool hero;
  final Color valueColor;
  final int badgeCount;
  final int index;
  final VoidCallback? onTap;

  const AdminKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.index,
    this.hero = false,
    this.valueColor = adminInk,
    this.badgeCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: hero ? petroleoColor : adminPaper,
            borderRadius: BorderRadius.circular(14),
            border: hero ? null : Border.all(color: adminLine),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          color: hero ? Colors.white54 : adminInkSoft)),
                  const SizedBox(height: 10),
                  Text(value,
                      style: TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: hero ? 38 : 30,
                          fontWeight: FontWeight.w500,
                          color: hero ? Colors.white : valueColor)),
                ],
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: BoxDecoration(
                      color: valueColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 60 * index))
        .fadeIn(duration: 340.ms)
        .slideY(begin: 0.10, end: 0, curve: Curves.easeOut);
  }
}

/// Entrada em cascata para itens de lista fora de um AdminPanel (grids de
/// cards, por exemplo).
class AdminFadeIn extends StatelessWidget {
  final int index;
  final Widget child;
  const AdminFadeIn({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: Duration(milliseconds: 45 * (index % 12)))
        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
        .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

/// Pílula de status (mesmo padrão do "status" no preview: contorno colorido).
class AdminStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const AdminStatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
