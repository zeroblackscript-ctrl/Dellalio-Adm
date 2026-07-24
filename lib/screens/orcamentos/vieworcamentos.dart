import 'package:DELLALIO/screens/orcamentos/editor_ambientes.dart';
import 'package:DELLALIO/screens/orcamentos/novo_rascunho.dart';
import 'package:DELLALIO/screens/orcamentos/rascunhos.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../core/theme.dart';

class ViewBudgetScreen extends StatelessWidget {
  final String orcamentoId;

  const ViewBudgetScreen({super.key, required this.orcamentoId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? DellalioTheme.darkBackground : DellalioTheme.lightBackground;

    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orcamentos').doc(orcamentoId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final rawData = snapshot.data?.data();
          if (rawData == null) {
            return Scaffold(
              backgroundColor: bgColor,
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          final data = rawData as Map<String, dynamic>;

          return Scaffold(
            backgroundColor: bgColor,
            body: DefaultTabController(
              length: 2,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    expandedHeight: 180,
                    pinned: true,
                    backgroundColor: petroleoColor,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.white),
                        tooltip: "EXCLUIR ORÇAMENTO",
                        onPressed: () => _showDeleteOrcamentoDialog(context, orcamentoId),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text((data['name'] ?? 'ORÇAMENTO').toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      background: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Image.asset('assets/imagens/logo/logo ld.png', fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ],
                body: Column(
                  children: [
                    Container(
                      color: petroleoColor,
                      child: const TabBar(
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        indicatorColor: Color(0xFFD4AF37),
                        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        tabs: [Tab(text: "DETALHES"), Tab(text: "PROJETOS/RASCUNHOS")],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildDetailsTab(data, isDark),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('orcamentos')
                                .doc(orcamentoId)
                                .collection('projects')
                                .snapshots(),
                            builder: (context, projectSnapshot) {
                              if (!projectSnapshot.hasData) return const Center(child: CircularProgressIndicator());

                              final listaProjetos = projectSnapshot.data!.docs
                                  .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
                                  .toList();

                              return _buildProjectsGrid(listaProjetos, isDark);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              unselectedItemColor: Colors.white70,
              backgroundColor: isDark ? const Color(0xFF0D0D0D) : petroleoColor,
              selectedItemColor: Colors.white,
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
                BottomNavigationBarItem(icon: Icon(Icons.add_business), label: "Novo Projeto"),
                BottomNavigationBarItem(icon: Icon(Icons.picture_as_pdf), label: "Gerar PDF"),
                BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: "Finalizar"),
              ],
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
        title: const Text("EXCLUIR ORÇAMENTO"),
        content: const Text(
          "Tem certeza que deseja excluir este orçamento? Todos os projetos vinculados a ele também serão removidos permanentemente. Esta ação não pode ser desfeita.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
                    content: Text("ORÇAMENTO EXCLUÍDO COM SUCESSO!"),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                debugPrint("Erro ao excluir orçamento: $e");
                messenger.showSnackBar(
                  SnackBar(content: Text("ERRO AO EXCLUIR: $e"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("SIM, EXCLUIR"),
          ),
        ],
      ),
    );
  }

  void _showFinalizarDialog(BuildContext context, String id, Map<String, dynamic> cData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("FINALIZAR ORÇAMENTO"),
        content: const Text("Converter orçamento em cliente ativo e migrar todos os projetos com suas especificações?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: petroleoColor, foregroundColor: Colors.white),
            onPressed: () async { /* ... lógica mantida ... */ Navigator.pop(ctx); },
            child: const Text("CONFIRMAR"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(Map<String, dynamic> data, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark ? const Color(0xFF0D0D0D) : Colors.white;
    final iconColor = petroleoColor;

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
      {"label": "NOME", "value": data['name']?.toString().toUpperCase() ?? '---', "icon": Icons.person},
      {"label": "CPF / CNPJ", "value": formattedDoc, "icon": Icons.badge},
      {"label": "TELEFONE", "value": formattedPhone, "icon": Icons.phone},
      {"label": "E-MAIL", "value": data['email'] ?? '---', "icon": Icons.email},
      {"label": "ENDEREÇO", "value": data['address'] ?? 'NÃO INFORMADO', "icon": Icons.home},
      {"label": "OBSERVAÇÕES", "value": data['notes'] ?? 'NENHUMA', "icon": Icons.notes},
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text("DADOS DO ORÇAMENTO",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: petroleoColor)),
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
                return _infoCard(items[index]['label'], items[index]['value'], items[index]['icon'], cardBg, textColor, iconColor);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon, Color cardBg, Color textColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.6))),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor), softWrap: true),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProjectsGrid(List<Map<String, dynamic>> projetos, bool isDark) {
    if (projetos.isEmpty) {
      return Center(
        child: Text("NENHUM PROJETO CADASTRADO",
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
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
        final String projectId = pData['id']?.toString() ?? '';

        return Card(
          color: cardColor,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ConfigurarAmbienteScreen(orcamentoId: orcamentoId),
              ));
            },
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  (pData['projectName'] ?? 'PROJETO').toUpperCase(),
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