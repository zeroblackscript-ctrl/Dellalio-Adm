import 'package:DELLALIO/screens/estoque/edit_item_screen.dart';
import 'package:DELLALIO/screens/estoque/register_item_screen.dart';
import 'package:DELLALIO/screens/estoque/stock_history_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';
import '../../core/user_session.dart';

class ManageStockScreen extends StatefulWidget {
  const ManageStockScreen({super.key});

  @override
  State<ManageStockScreen> createState() => _ManageStockScreenState();
}

class _ManageStockScreenState extends State<ManageStockScreen> {
  String _searchQuery = "";

  bool _isStockCritical(int current, int min) {
    return current <= (min + 10);
  }

  void _showCriticalStockDialog(BuildContext context, String itemName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: inkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: panelRust, size: 20),
            const SizedBox(width: 8),
            Text(
              "Alerta de estoque",
              style: TextStyle(
                color: panelIvory,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          "O item $itemName está com o estoque perigosamente baixo. Reponha o quanto antes.",
          style: TextStyle(color: panelSlate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Entendi",
              style: TextStyle(
                color: dellalioGoldSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = UserSession.isAdmin();

    return Scaffold(
      backgroundColor: inkPageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    "Gerenciar estoque",
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontWeight: FontWeight.w500,
                      fontSize: 27,
                      color: dellalioTitle,
                    ),
                  ),
                ),
                if (isAdmin) ...[
                  DellalioIconGhostButton(
                    icon: Icons.history,
                    tooltip: 'Histórico de retiradas',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StockHistoryScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DellalioGoldButton(
                    label: "Novo produto",
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RegisterItemScreen()),
                    ),
                  ),
                ],
              ],
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
            const SizedBox(height: 22),
            DellalioSearchField(
              hint: "Buscar produto",
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 80.ms)
                .slideY(begin: -0.04, end: 0),
            const SizedBox(height: 26),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stock')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: dellalioGold),
                    ),
                  );
                }

                var docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['name'] ?? '').toString().toLowerCase().contains(
                    _searchQuery,
                  );
                }).toList();

                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      "Nenhum produto encontrado.",
                      style: TextStyle(color: panelSlate),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    Map<String, dynamic> data =
                        doc.data() as Map<String, dynamic>;
                    return _StockCard(
                      docId: doc.id,
                      data: data,
                      isAdmin: isAdmin,
                      delayIndex: index % 12,
                      isCritical: _isStockCritical(
                        data['quantity'] ?? 0,
                        data['minQuantity'] ?? 0,
                      ),
                      onCriticalTap: () => _showCriticalStockDialog(
                        context,
                        data['name'] ?? 'Item',
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de produto — aro dourado (ok) ou terracota pulsante (crítico),
/// nome, pill de quantidade e rodapé "ver detalhes" com o rótulo certo
/// pra cada papel de usuário.
class _StockCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isAdmin;
  final bool isCritical;
  final int delayIndex;
  final VoidCallback onCriticalTap;

  const _StockCard({
    required this.docId,
    required this.data,
    required this.isAdmin,
    required this.isCritical,
    required this.delayIndex,
    required this.onCriticalTap,
  });

  @override
  State<_StockCard> createState() => _StockCardState();
}

class _StockCardState extends State<_StockCard> {
  bool _hover = false;

  String get _footerLabel {
    if (!widget.isAdmin) return "Ver detalhes";
    return widget.isCritical ? "Repor estoque" : "Editar item";
  }

  void _open(BuildContext context) {
    if (widget.isCritical) widget.onCriticalTap();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditItemScreen(docId: widget.docId, data: widget.data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int quantity = widget.data['quantity'] ?? 0;
    final int minQuantity = widget.data['minQuantity'] ?? 0;
    final String name = (widget.data['name'] ?? 'SEM NOME')
        .toString()
        .toUpperCase();
    final String imageUrl = widget.data['imageUrl'] ?? '';
    final Color ring = widget.isCritical ? panelRust : dellalioGold;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _open(context),
        child:
            AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  decoration: BoxDecoration(
                    color: _hover ? inkSurfaceHover : inkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: hairline),
                  ),
                  child: Column(
                    children: [
                      _StockThumb(
                        imageUrl: imageUrl,
                        ring: ring,
                        pulse: widget.isCritical,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: panelIvory,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: (widget.isCritical ? panelRust : dellalioGold)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                (widget.isCritical ? panelRust : dellalioGold)
                                    .withValues(alpha: 0.38),
                          ),
                        ),
                        child: Text(
                          "QTD $quantity · MIN $minQuantity",
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.4,
                            color: widget.isCritical
                                ? const Color(0xFFE39A85)
                                : dellalioGoldSoft,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: hairline)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.isAdmin
                                  ? Icons.edit_outlined
                                  : Icons.visibility_outlined,
                              size: 14,
                              color: _hover ? dellalioGoldSoft : panelSlate,
                            ),
                            SizedBox(width: _hover ? 9 : 6),
                            Text(
                              _footerLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.5,
                                color: _hover ? dellalioGoldSoft : panelSlate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .animate(delay: (60 * widget.delayIndex).ms)
                .fadeIn(duration: 420.ms, curve: Curves.easeOut)
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
      ),
    );
  }
}

class _StockThumb extends StatelessWidget {
  final String imageUrl;
  final Color ring;
  final bool pulse;
  const _StockThumb({
    required this.imageUrl,
    required this.ring,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: inkPageBg,
        border: Border.all(color: ring, width: 1.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? Center(
              child: Text(
                'D',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 22,
                  color: dellalioGoldSoft,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: dellalioGold),
              ),
              errorWidget: (context, url, error) => Center(
                child: Text(
                  'D',
                  style: TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 22,
                    color: dellalioGoldSoft,
                  ),
                ),
              ),
            ),
    );

    if (!pulse) return thumb;

    return Stack(
      alignment: Alignment.center,
      children: [
        thumb,
        IgnorePointer(
          child:
              Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: panelRust, width: 1),
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
