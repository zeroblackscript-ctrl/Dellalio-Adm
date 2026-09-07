import 'package:DELLALIO/screens/clientes/projects/criar_projeto.dart';
import 'package:DELLALIO/screens/clientes/projects/projectsview_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/dellalio_kit.dart';
import '../../core/pdf_cover_card.dart';
import '../../core/user_session.dart';
import '../../core/theme.dart';

class ViewClientScreen extends StatelessWidget {
  final String clientId;
  const ViewClientScreen({super.key, required this.clientId});

  Future<void> _deleteClient(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: inkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text("Excluir cliente", style: TextStyle(color: panelIvory)),
        content: Text(
          "Tem certeza que deseja excluir este cliente permanentemente? Esta ação não pode ser desfeita.",
          style: TextStyle(color: panelSlate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancelar", style: TextStyle(color: panelSlate)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Excluir", style: TextStyle(color: panelRust)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      try {
        final firestore = FirebaseFirestore.instance;
        final clientRef = firestore.collection('clients').doc(clientId);

        final projectsSnap = await clientRef.collection('projects').get();

        final orcamentosSnap = await firestore
            .collection('orcamentos')
            .where('clientId', isEqualTo: clientId)
            .get();

        final batch = firestore.batch();

        for (final doc in projectsSnap.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(clientRef);

        for (final orcamentoDoc in orcamentosSnap.docs) {
          final orcamentoProjectsSnap = await orcamentoDoc.reference
              .collection('projects')
              .get();
          for (final projectDoc in orcamentoProjectsSnap.docs) {
            batch.delete(projectDoc.reference);
          }
          batch.delete(orcamentoDoc.reference);
        }

        await batch.commit();

        messenger.showSnackBar(
          const SnackBar(content: Text("Cliente excluído com sucesso!")),
        );
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text("Erro ao excluir: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .snapshots(),
        builder: (context, clientSnapshot) {
          if (!clientSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: dellalioGold),
            );
          }

          final rawData = clientSnapshot.data?.data();
          if (rawData == null) {
            return const Center(
              child: CircularProgressIndicator(color: dellalioGold),
            );
          }
          final data = rawData as Map<String, dynamic>;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('clients')
                .doc(clientId)
                .collection('projects')
                .snapshots(),
            builder: (context, projectSnapshot) {
              final projectData =
                  (projectSnapshot.hasData &&
                      projectSnapshot.data!.docs.isNotEmpty)
                  ? projectSnapshot.data!.docs.first.data()
                        as Map<String, dynamic>
                  : <String, dynamic>{};

              return DefaultTabController(
                length: 5,
                child: Scaffold(
                  backgroundColor: inkPageBg,
                  body: Column(
                    children: [
                      DellalioSubHeader(
                        title: (data['name'] ?? 'Cliente').toString(),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: hairline)),
                        ),
                        child: TabBar(
                          indicatorColor: dellalioGold,
                          labelColor: panelIvory,
                          unselectedLabelColor: panelSlate,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          isScrollable: true,
                          tabs: const [
                            Tab(text: "Detalhes"),
                            Tab(text: "Projetos"),
                            Tab(text: "Fotos"),
                            Tab(text: "PDFs"),
                            Tab(text: "Documentos"),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildDetailsTab(context, data, projectData),
                            _buildProjectsGrid(clientId),
                            _buildGalleryTab(projectData['galleryUrls']),
                            _buildFilesTab(context, projectData['files']),
                            _buildDocumentsTab(projectData['contratos']),
                          ],
                        ),
                      ),
                    ],
                  ),
                  floatingActionButton: FloatingActionButton(
                    backgroundColor: dellalioGold,
                    foregroundColor: inkPageBg,
                    child: const Icon(Icons.add),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CreateProjectScreen(clientId: clientId),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProjectsGrid(String clientId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('projects')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: dellalioGold),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const DellalioEmptyState(
            icon: Icons.folder_open,
            title: "Nenhum projeto registrado",
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final pData = docs[index].data() as Map<String, dynamic>;
            final String corHex = pData['corProjeto']?.toString() ?? '#00695C';
            final Color cardColor = DellalioTheme.colorFromHex(corHex);

            return Card(
              color: cardColor,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectDetailScreen(
                        projectId: docs[index].id,
                        clientId: clientId,
                      ),
                    ),
                  );
                },
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      (pData['projectName'] ?? 'Projeto').toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDocumentsTab(List<dynamic>? documentos) {
    return PdfCoverGrid(
      items: documentos,
      emptyTitle: "Nenhum documento anexado",
    );
  }

  Widget _buildDetailsTab(
    BuildContext context,
    Map<String, dynamic> data,
    Map<String, dynamic> projectData,
  ) {
    final String rawPhone = data['phone'] ?? '';
    final String formattedPhone = rawPhone.isNotEmpty
        ? MaskTextInputFormatter(
            mask: '(##) #####-####',
            filter: {"#": RegExp(r'[0-9]')},
          ).maskText(rawPhone)
        : '---';

    final String rawDoc = data['document'] ?? '';
    final String formattedDoc = rawDoc.isNotEmpty
        ? MaskTextInputFormatter(
            mask: rawDoc.length > 11 ? '##.###.###/####-##' : '###.###.###-##',
            filter: {"#": RegExp(r'[0-9]')},
          ).maskText(rawDoc)
        : '---';

    final List<Map<String, dynamic>> items = [
      {"label": "CPF / CNPJ", "value": formattedDoc, "icon": Icons.badge},
      {"label": "Telefone", "value": formattedPhone, "icon": Icons.phone},
      {"label": "E-mail", "value": data['email'] ?? '---', "icon": Icons.email},
      {
        "label": "Endereço",
        "value": data['address'] ?? 'Não informado',
        "icon": Icons.home,
      },
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 10),
            Text(
              "Informações",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: panelSlate,
              ),
            ),
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
                return _infoCard(
                  items[index]['label'],
                  items[index]['value'],
                  items[index]['icon'],
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              "Observações",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: panelSlate,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: inkSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: hairline),
              ),
              child: Text(
                data['notes'] ?? 'Nenhuma observação.',
                style: TextStyle(fontSize: 14, color: panelIvory),
              ),
            ),
            const SizedBox(height: 40),
            if (UserSession.isAdmin())
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: () => _deleteClient(context),
                  icon: const Icon(Icons.delete_forever, color: Colors.white),
                  label: const Text("Excluir cliente"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: panelRust,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            const SizedBox(height: 20),
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
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: panelSlateDim),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: panelIvory,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryTab(List<dynamic>? urls) {
    if (urls == null || urls.isEmpty) {
      return const DellalioEmptyState(
        icon: Icons.photo_outlined,
        title: "Nenhuma imagem",
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: urls.length,
      itemBuilder: (ctx, i) => InkWell(
        onTap: () => showDialog(
          context: ctx,
          builder: (_) => Dialog(child: CachedNetworkImage(imageUrl: urls[i])),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: urls[i],
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: inkSurface),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
      ),
    );
  }

  Widget _buildFilesTab(BuildContext context, List<dynamic>? files) {
    return PdfCoverGrid(items: files, emptyTitle: "Nenhum arquivo");
  }
}
