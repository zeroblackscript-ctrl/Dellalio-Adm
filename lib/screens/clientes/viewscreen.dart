import 'package:DELLALIO/screens/clientes/projects/criar_projeto.dart';
import 'package:DELLALIO/screens/clientes/projects/projectsview_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/user_session.dart';
import '../../core/theme.dart';

class ViewClientScreen extends StatelessWidget {
  final String clientId;
  const ViewClientScreen({super.key, required this.clientId});

  Future<void> _deleteClient(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("EXCLUIR CLIENTE"),
        content: const Text(
            "Tem certeza que deseja excluir este cliente permanentemente? Esta ação não pode ser desfeita."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("CANCELAR")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text("EXCLUIR", style: TextStyle(color: Colors.red)),
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

        final projectsSnap =
            await clientRef.collection('projects').get();

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
          final orcamentoProjectsSnap =
              await orcamentoDoc.reference.collection('projects').get();
          for (final projectDoc in orcamentoProjectsSnap.docs) {
            batch.delete(projectDoc.reference);
          }
          batch.delete(orcamentoDoc.reference);
        }

        await batch.commit();

        messenger.showSnackBar(const SnackBar(
            content: Text("CLIENTE EXCLUÍDO COM SUCESSO!")));
      } catch (e) {
        messenger
            .showSnackBar(SnackBar(content: Text("ERRO AO EXCLUIR: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF0F2F5),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .snapshots(),
        builder: (context, clientSnapshot) {
          if (!clientSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawData = clientSnapshot.data?.data();
          if (rawData == null) {
            return const Center(child: CircularProgressIndicator());
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
                child: NestedScrollView(
                  headerSliverBuilder:
                      (context, innerBoxIsScrolled) => [
                    SliverAppBar(
                      expandedHeight: 180,
                      pinned: true,
                      backgroundColor: petroleoColor,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          (data['name'] ?? 'CLIENTE').toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        background: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Image.asset(
                            'assets/imagens/logo/logo ld.png',
                            fit: BoxFit.contain,
                          ),
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
                          labelStyle: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                          unselectedLabelStyle: TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 12),
                          tabs: [
                            Tab(text: "DETALHES"),
                            Tab(text: "PROJETOS"),
                            Tab(text: "FOTOS"),
                            Tab(text: "PDFS"),
                            Tab(text: "DOCUMENTOS"),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildDetailsTab(context, data, projectData),
                            _buildProjectsGrid(clientId),
                            _buildGalleryTab(projectData['galleryUrls']),
                            _buildFilesTab(projectData['files']),
                            _buildDocumentsTab(projectData['contratos']),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: petroleoColor,
        child: const Icon(Icons.add, color: Colors.white),
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
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
              child: Text("NENHUM PROJETO REGISTRADO",
                  style: TextStyle(fontWeight: FontWeight.w500)));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final pData =
                docs[index].data() as Map<String, dynamic>;
            final String corHex =
                pData['corProjeto']?.toString() ?? '#00695C';
            final Color cardColor = DellalioTheme.colorFromHex(corHex);

            return Card(
              color: cardColor,
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
                      (pData['projectName'] ?? 'PROJETO')
                          .toUpperCase(),
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
    if (documentos == null || documentos.isEmpty) {
      return const Center(child: Text("NENHUM DOCUMENTO ANEXADO"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: documentos.length,
      itemBuilder: (ctx, i) {
        final doc = documentos[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading:
                const Icon(Icons.description, color: Colors.blueGrey),
            title: Text(
                ((doc as Map)['name'] ?? 'DOCUMENTO SEM NOME')
                    .toString()
                    .toUpperCase()),
            trailing: const Icon(Icons.visibility),
            onTap: () {
              if (doc['url'] != null) {
                launchUrl(Uri.parse(doc['url']),
                    mode: LaunchMode.externalApplication);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildDetailsTab(BuildContext context, Map<String, dynamic> data,
      Map<String, dynamic> projectData) {
    String formattedDate = '--/--';
    if (projectData.containsKey('deliveryDate') &&
        projectData['deliveryDate'] != null) {
      final dynamic deliveryValue = projectData['deliveryDate'];
      if (deliveryValue is Timestamp) {
        DateTime date = deliveryValue.toDate();
        formattedDate =
            "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
      } else {
        formattedDate = deliveryValue.toString();
      }
    }

    final String rawPhone = data['phone'] ?? '';
    final String formattedPhone = rawPhone.isNotEmpty
        ? MaskTextInputFormatter(
                mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')})
            .maskText(rawPhone)
        : '---';

    final String rawDoc = data['document'] ?? '';
    final String formattedDoc = rawDoc.isNotEmpty
        ? MaskTextInputFormatter(
                mask: rawDoc.length > 11
                    ? '##.###.###/####-##'
                    : '###.###.###-##',
                filter: {"#": RegExp(r'[0-9]')})
            .maskText(rawDoc)
        : '---';

    final List<Map<String, dynamic>> items = [
      {
        "label": "CPF / CNPJ",
        "value": formattedDoc,
        "icon": Icons.badge
      },
      {
        "label": "TELEFONE",
        "value": formattedPhone,
        "icon": Icons.phone
      },
      {
        "label": "E-MAIL",
        "value": data['email'] ?? '---',
        "icon": Icons.email
      },
      {
        "label": "ENDEREÇO",
        "value": data['address'] ?? 'NÃO INFORMADO',
        "icon": Icons.home
      },
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 10),
            const Text("INFORMAÇÕES",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: petroleoColor)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 6,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                mainAxisExtent: 120,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _infoCard(items[index]['label'],
                    items[index]['value'], items[index]['icon']);
              },
            ),
            const SizedBox(height: 20),
            const Text("OBSERVAÇÕES",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: petroleoColor)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                data['notes'] ?? 'NENHUMA OBSERVAÇÃO.',
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(height: 40),
            if (UserSession.isAdmin())
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: () => _deleteClient(context),
                  icon: const Icon(Icons.delete_forever,
                      color: Colors.white),
                  label: const Text("EXCLUIR CLIENTE"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: petroleoColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color.fromARGB(255, 78, 78, 78))),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    softWrap: true),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGalleryTab(List<dynamic>? urls) {
    if (urls == null || urls.isEmpty) {
      return const Center(child: Text("NENHUMA IMAGEM"));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate:
          const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: urls.length,
      itemBuilder: (ctx, i) => InkWell(
        onTap: () => showDialog(
            context: ctx,
            builder: (_) => Dialog(
                child: CachedNetworkImage(imageUrl: urls[i]))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: urls[i],
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(color: Colors.grey[300]),
            errorWidget: (context, url, error) =>
                const Icon(Icons.error),
          ),
        ),
      ),
    );
  }

  Widget _buildFilesTab(List<dynamic>? files) {
    if (files == null || files.isEmpty) {
      return const Center(child: Text("NENHUM ARQUIVO"));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: files.length,
      itemBuilder: (ctx, i) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: const Icon(Icons.picture_as_pdf,
              color: Colors.red),
          title: Text(
              ((files[i] as Map)['name'] ?? 'ARQUIVO')
                  .toString()
                  .toUpperCase()),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => launchUrl(
              Uri.parse(files[i]['url']),
              mode: LaunchMode.externalApplication),
        ),
      ),
    );
  }
}