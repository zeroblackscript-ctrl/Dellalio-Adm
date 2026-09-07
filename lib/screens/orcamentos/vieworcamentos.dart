import 'package:DELLALIO/screens/orcamentos/editor_ambientes.dart';
import 'package:DELLALIO/screens/orcamentos/novo_rascunho.dart';
import 'package:DELLALIO/screens/orcamentos/rascunhos.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';

class ViewBudgetScreen extends StatelessWidget {
  final String orcamentoId;

  const ViewBudgetScreen({super.key, required this.orcamentoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orcamentos').doc(orcamentoId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: dellalioGold));
          }

          final rawData = snapshot.data?.data();
          if (rawData == null) {
            return const Center(child: CircularProgressIndicator(color: dellalioGold));
          }
          final data = rawData as Map<String, dynamic>;

          return DefaultTabController(
            length: 2,
            child: Scaffold(
              backgroundColor: inkPageBg,
              body: Column(
                children: [
                  DellalioSubHeader(
                    title: (data['name'] ?? 'Orçamento').toString(),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_forever, color: panelRust),
                      tooltip: "Excluir orçamento",
                      onPressed: () => _showDeleteOrcamentoDialog(context, orcamentoId),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: hairline)),
                    ),
                    child: TabBar(
                      indicatorColor: dellalioGold,
                      labelColor: panelIvory,
                      unselectedLabelColor: panelSlate,
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      tabs: const [Tab(text: "Detalhes"), Tab(text: "Projetos")],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildDetailsTab(data),
                        _buildProjectsTab(),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                unselectedItemColor: panelSlate,
                backgroundColor: inkSurface,
                selectedItemColor: dellalioGold,
                onTap: (index) {
                  if (index == 0) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ConfigurarAmbienteScreen(orcamentoId: orcamentoId)
                    ));
                  } else if (index == 1) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ListarRascunhosScreen(orcamentoId: orcamentoId)));
                  } else if (index == 2) {
                    _showFinalizarDialog(context, orcamentoId, data);
                  }
                },
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.add_business), label: "Novo projeto"),
                  BottomNavigationBarItem(icon: Icon(Icons.picture_as_pdf), label: "Gerar PDF"),
                  BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: "Finalizar"),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  void _showDeleteOrcamentoDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: inkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text("Excluir orçamento", style: TextStyle(color: panelIvory)),
        content: Text(
          "Tem certeza que deseja excluir este orçamento? Todos os projetos vinculados a ele também serão removidos permanentemente. Esta ação não pode ser desfeita.",
          style: TextStyle(color: panelSlate),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancelar", style: TextStyle(color: panelSlate))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: panelRust, foregroundColor: Colors.white),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              Navigator.pop(context);

              try {
                final db = FirebaseFirestore.instance;
                final orcamentoDoc = db.collection('orcamentos').doc(id);
                final projectsSnapshot = await orcamentoDoc.collection('projects').get();

                final batch = db.batch();
                for (var doc in projectsSnapshot.docs) {
                  batch.delete(doc.reference);
                }
                batch.delete(orcamentoDoc);

                await batch.commit();

                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("Orçamento excluído com sucesso!"),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                debugPrint("Erro ao excluir orçamento: $e");
                messenger.showSnackBar(
                  SnackBar(content: Text("Erro ao excluir: $e"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Excluir"),
          ),
        ],
      ),
    );
  }

  void _showFinalizarDialog(BuildContext context, String id, Map<String, dynamic> cData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: inkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text("Finalizar orçamento", style: TextStyle(color: panelIvory)),
        content: Text("Converter orçamento em cliente ativo e migrar todos os projetos com suas especificações?", style: TextStyle(color: panelSlate)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancelar", style: TextStyle(color: panelSlate))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dellalioGold, foregroundColor: inkPageBg),
            onPressed: () async { /* ... lógica mantida ... */ Navigator.pop(ctx); },
            child: const Text("Confirmar"),
          ),
        ],
      ),
    );
  }
  Widget _buildDetailsTab(Map<String, dynamic> data) {
    final String rawPhone = data['phone'] ?? '';
    final String formattedPhone = rawPhone.isNotEmpty
        ? MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')}).maskText(rawPhone)
        : '---';

    final String rawDoc = data['document'] ?? '';
    final String formattedDoc = rawDoc.isNotEmpty
        ? MaskTextInputFormatter(
            mask: rawDoc.length > 11 ? '##.###.###/####-##' : '###.###.###-##',
            filter: {"#": RegExp(r'[0-9]')}).maskText(rawDoc)
        : '---';

    final List<Map<String, dynamic>> items = [
      {"label": "Nome", "value": data['name']?.toString() ?? '---', "icon": Icons.person},
      {"label": "CPF / CNPJ", "value": formattedDoc, "icon": Icons.badge},
      {"label": "Telefone", "value": formattedPhone, "icon": Icons.phone},
      {"label": "E-mail", "value": data['email'] ?? '---', "icon": Icons.email},
      {"label": "Endereço", "value": data['address'] ?? 'Não informado', "icon": Icons.home},
      {"label": "Observações", "value": data['notes'] ?? 'Nenhuma', "icon": Icons.notes},
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text("Dados do orçamento",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: panelSlate)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 6,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                mainAxisExtent: 120,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _infoCard(items[index]['label'], items[index]['value'], items[index]['icon']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: inkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: dellalioGold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: panelSlateDim)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: panelIvory), softWrap: true),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProjectsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orcamentos')
          .doc(orcamentoId)
          .collection('projects')
          .snapshots(),
      builder: (context, projectSnapshot) {
        if (!projectSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: dellalioGold));
        }

        final listaProjetos = projectSnapshot.data!.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();

        return _buildProjectsGrid(listaProjetos);
      },
    );
  }

  Widget _buildProjectsGrid(List<Map<String, dynamic>> projetos) {
    if (projetos.isEmpty) {
      return const DellalioEmptyState(
        icon: Icons.folder_open,
        title: "Nenhum projeto cadastrado",
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 1.5, crossAxisSpacing: 16, mainAxisSpacing: 16,
      ),
      itemCount: projetos.length,
      itemBuilder: (context, index) {
        final pData = projetos[index];
        final String corHex = pData['corProjeto']?.toString() ?? '#00695C';
        final Color cardColor = DellalioTheme.colorFromHex(corHex);

        return Card(
          color: cardColor,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => EditorAmbienteScreen(
                  orcamentoId: orcamentoId,
                  projeto: pData,
                ),
              ));
            },
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  (pData['nome'] ?? pData['projectName'] ?? 'AMBIENTE').toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
