import 'package:DELLALIO/screens/orcamentos/criarorcamento.dart';
import 'package:DELLALIO/screens/orcamentos/editorcamento.dart';
import 'package:DELLALIO/screens/orcamentos/vieworcamentos.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';

class ManageOrcamentosListScreen extends StatefulWidget {
  const ManageOrcamentosListScreen({super.key});

  @override
  State<ManageOrcamentosListScreen> createState() =>
      _ManageOrcamentosListScreenState();
}

class _ManageOrcamentosListScreenState
    extends State<ManageOrcamentosListScreen> {
  String _searchQuery = "";

  void _showSelectClientDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: inkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            "Selecione o cliente",
            style: TextStyle(
              color: panelIvory,
              fontWeight: FontWeight.w500,
              fontSize: 17,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clients')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: dellalioGold),
                  );
                }

                final clients = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final clientData =
                        clients[index].data() as Map<String, dynamic>;
                    final clientId = clients[index].id;

                    return ListTile(
                      title: Text(
                        clientData['name'] ?? 'Sem nome',
                        style: TextStyle(color: panelIvory, fontSize: 14),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: panelSlate,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateFullClientAndBudgetScreen(
                              preselectedClientId: clientId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DellalioSearchField(
                    hint: "Buscar orçamento",
                    onChanged: (value) =>
                        setState(() => _searchQuery = value.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 14),
                DellalioGhostButton(
                  label: "Projeto p/ cliente existente",
                  icon: Icons.move_to_inbox_outlined,
                  onPressed: () => _showSelectClientDialog(context),
                ),
                const SizedBox(width: 10),
                DellalioGoldButton(
                  label: "Novo orçamento",
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateFullClientAndBudgetScreen(),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
            const SizedBox(height: 26),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orcamentos')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: dellalioGold),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      "Nenhum orçamento encontrado.",
                      style: TextStyle(color: panelSlate),
                    ),
                  );
                }

                var docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['name']?.toString().toLowerCase().contains(
                        _searchQuery,
                      ) ??
                      false;
                }).toList();

                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      "Nenhum orçamento encontrado.",
                      style: TextStyle(color: panelSlate),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.9,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) =>
                      _OrcamentoCard(doc: docs[index], delayIndex: index % 12),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OrcamentoCard extends StatefulWidget {
  final DocumentSnapshot doc;
  final int delayIndex;
  const _OrcamentoCard({required this.doc, required this.delayIndex});

  @override
  State<_OrcamentoCard> createState() => _OrcamentoCardState();
}

class _OrcamentoCardState extends State<_OrcamentoCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final String name = data['name']?.toString().toUpperCase() ?? "SEM NOME";

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child:
          AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                decoration: BoxDecoration(
                  color: _hover ? inkSurfaceHover : inkSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ViewBudgetScreen(orcamentoId: widget.doc.id),
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: panelIvory,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              Editorcamento(orcamentoId: widget.doc.id),
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: hairline)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 13,
                              color: _hover ? dellalioGoldSoft : panelSlate,
                            ),
                            SizedBox(width: _hover ? 9 : 6),
                            Text(
                              "EDITAR ORÇAMENTO",
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.5,
                                color: _hover ? dellalioGoldSoft : panelSlate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .animate(delay: (50 * widget.delayIndex).ms)
              .fadeIn(duration: 420.ms, curve: Curves.easeOut)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
    );
  }
}
