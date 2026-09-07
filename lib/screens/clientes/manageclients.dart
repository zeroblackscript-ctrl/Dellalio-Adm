import 'package:DELLALIO/screens/clientes/editclients.dart';
import 'package:DELLALIO/screens/clientes/register_client_screen.dart';
import 'package:DELLALIO/screens/clientes/viewscreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';

class ManageClientsListScreen extends StatefulWidget {
  const ManageClientsListScreen({super.key});

  @override
  State<ManageClientsListScreen> createState() =>
      _ManageClientsListScreenState();
}

class _ManageClientsListScreenState extends State<ManageClientsListScreen> {
  String _searchQuery = "";

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pedido':
        return statusPedido;
      case 'conferencia':
        return statusConferencia;
      case 'producao':
        return statusProducao;
      case 'montagem':
        return statusMontagem;
      case 'entrega':
        return statusEntrega;
      case 'finalizado':
        return statusFinalizado;
      default:
        return panelSlate;
    }
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
            Text(
              "Clientes",
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w500,
                fontSize: 27,
                color: dellalioTitle,
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
            const SizedBox(height: 22),
            Row(
                  children: [
                    Expanded(
                      child: DellalioSearchField(
                        hint: "Buscar cliente",
                        onChanged: (value) =>
                            setState(() => _searchQuery = value.toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 14),
                    DellalioGoldButton(
                      label: "Novo cliente",
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterClientScreen(),
                        ),
                      ),
                    ),
                  ],
                )
                .animate()
                .fadeIn(duration: 400.ms, delay: 80.ms)
                .slideY(begin: -0.04, end: 0),
            const SizedBox(height: 26),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clients')
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
                  return data['name']?.toString().toLowerCase().contains(
                        _searchQuery,
                      ) ??
                      false;
                }).toList();

                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      "Nenhum cliente encontrado.",
                      style: TextStyle(color: panelSlate),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.75,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final id = docs[index].id;
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _ClientCard(
                      clientId: id,
                      name: (data['name'] ?? 'SEM NOME')
                          .toString()
                          .toUpperCase(),
                      delayIndex: index % 12,
                      statusColorOf: _getStatusColor,
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

/// Card de cliente — nome, pill de status (pontinho colorido pela etapa
/// do pipeline) e rodapé "editar cliente".
class _ClientCard extends StatefulWidget {
  final String clientId;
  final String name;
  final int delayIndex;
  final Color Function(String status) statusColorOf;

  const _ClientCard({
    required this.clientId,
    required this.name,
    required this.delayIndex,
    required this.statusColorOf,
  });

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
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
                                ViewClientScreen(clientId: widget.clientId),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                color: panelIvory,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('clients')
                                  .doc(widget.clientId)
                                  .collection('projects')
                                  .snapshots(),
                              builder: (context, projectSnapshot) {
                                if (!projectSnapshot.hasData) {
                                  return DellalioStatusPill(
                                    label: "CARREGANDO",
                                    color: panelSlate,
                                    neutral: true,
                                  );
                                }
                                final projects = projectSnapshot.data!.docs;
                                if (projects.isEmpty) {
                                  return DellalioStatusPill(
                                    label: "SEM PROJETOS",
                                    color: panelSlate,
                                    neutral: true,
                                  );
                                }
                                final pData =
                                    projects.first.data()
                                        as Map<String, dynamic>;
                                final status = (pData['status'] ?? 'vendas')
                                    .toString();
                                return DellalioStatusPill(
                                  label: status.toUpperCase(),
                                  color: widget.statusColorOf(status),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EditClientScreen(clientId: widget.clientId),
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
                              "EDITAR CLIENTE",
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

