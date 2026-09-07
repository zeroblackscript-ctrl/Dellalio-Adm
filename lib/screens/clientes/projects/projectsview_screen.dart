import 'package:DELLALIO/screens/clientes/projects/editprojects_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/dellalio_kit.dart';
import '../../../core/pdf_cover_card.dart';
import '../../../core/theme.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String clientId;
  final String projectId;

  const ProjectDetailScreen({
    super.key,
    required this.clientId,
    required this.projectId,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkIfAdmin();
  }

  Future<void> _checkIfAdmin() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (userDoc.exists && mounted) {
      final data = userDoc.data() as Map<String, dynamic>;
      setState(() {
        _isAdmin = data['role'] == 'admin' || data['isAdmin'] == true;
      });
    }
  }

  Future<void> _deleteProject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: inkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('Excluir projeto', style: TextStyle(color: panelIvory)),
        content: Text(
          'Tem certeza que deseja excluir este projeto? Esta ação não pode ser desfeita.',
          style: TextStyle(color: panelSlate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: panelSlate)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: panelRust),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final projectSnap = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('projects')
          .doc(widget.projectId)
          .get();

      if (projectSnap.exists) {
        final data = projectSnap.data() as Map<String, dynamic>;
        final List<dynamic> files = data['files'] ?? [];
        final List<dynamic> galleryUrls = data['galleryUrls'] ?? [];
        final List<dynamic> contratos = data['contratos'] ?? [];

        for (final file in [...files, ...galleryUrls, ...contratos]) {
          try {
            final url = file is Map ? file['url'] : file?.toString();
            if (url != null && url.isNotEmpty) {
              await FirebaseStorage.instance.refFromURL(url).delete();
            }
          } catch (_) {}
        }
      }

      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('projects')
          .doc(widget.projectId)
          .delete();

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Projeto excluído com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(content: Text('Erro ao excluir projeto: $e')),
        );
      }
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '--/--';
    if (dateValue is Timestamp) {
      DateTime date = dateValue.toDate();
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }
    return dateValue.toString();
  }

  String _formatMoney(dynamic value) {
    if (value == null) return "0,00";
    final double v = value is num
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0.0;
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .snapshots(),
      builder: (context, clientSnap) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clients')
              .doc(widget.clientId)
              .collection('projects')
              .doc(widget.projectId)
              .snapshots(),
          builder: (context, projectSnap) {
            if (!clientSnap.hasData || !projectSnap.hasData) {
              return Scaffold(
                backgroundColor: inkPageBg,
                body: const Center(
                  child: CircularProgressIndicator(color: dellalioGold),
                ),
              );
            }

            if (!projectSnap.data!.exists) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pop(context);
                }
              });
              return Scaffold(
                backgroundColor: inkPageBg,
                body: const Center(
                  child: CircularProgressIndicator(color: dellalioGold),
                ),
              );
            }

            final clientData = clientSnap.data!.data() as Map<String, dynamic>;
            final projectData =
                projectSnap.data!.data() as Map<String, dynamic>;

            final String projectName =
                (projectData['projectName'] ?? projectData['nome'])
                    ?.toString() ??
                "Projeto";

            return DefaultTabController(
              length: 4,
              child: Scaffold(
                backgroundColor: inkPageBg,
                body: Column(
                  children: [
                    DellalioSubHeader(
                      title: projectName,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isAdmin)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: panelRust,
                              ),
                              tooltip: "Excluir projeto",
                              onPressed: _deleteProject,
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: dellalioGold,
                            ),
                            tooltip: "Editar projeto",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProjectScreen(
                                    clientId: widget.clientId,
                                    projectId: widget.projectId,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        tabs: const [
                          Tab(text: "Info"),
                          Tab(text: "Fotos"),
                          Tab(text: "PDFs"),
                          Tab(text: "Documentos"),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildInfoTab(clientData, projectData),
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
    );
  }

  Widget _buildInfoTab(
    Map<String, dynamic> client,
    Map<String, dynamic> project,
  ) {
    final String projectAddress = (project['address'] ?? '').toString().trim();
    final String address = projectAddress.isNotEmpty
        ? projectAddress
        : (client['address'] ?? 'Não informado').toString();
    final String cep = (project['cep'] ?? '').toString().trim();
    final String deliveryDate = _formatDate(project['deliveryDate']);

    final String corCaixa = (project['corCaixa'] ?? '').toString();
    final String corAcab = (project['corAcab'] ?? '').toString();
    final List extras = project['extras'] ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle("Dados do cliente"),
        _infoTile(Icons.person, (client['name'] ?? '---').toString(), "Nome"),
        _infoTile(
          Icons.phone,
          (client['phone'] ?? '---').toString(),
          "Telefone",
        ),
        const SizedBox(height: 16),
        _sectionTitle("Dados da obra"),
        _infoTile(Icons.home, address, "Endereço da obra"),
        if (cep.isNotEmpty) _infoTile(Icons.markunread_mailbox, cep, "CEP"),
        _infoTile(
          Icons.info,
          (project['status'] ?? 'Pendente').toString(),
          "Status do projeto",
        ),
        _infoTile(Icons.calendar_today, deliveryDate, "Entrega"),
        if ((project['formaPagamento'] ?? '').toString().isNotEmpty)
          _infoTile(
            Icons.payments,
            project['formaPagamento'].toString(),
            "Forma de pagamento",
          ),
        if ((project['notes'] ?? '').toString().isNotEmpty)
          _infoTile(Icons.notes, project['notes'].toString(), "Observações"),
        const SizedBox(height: 16),
        _sectionTitle("Especificações técnicas"),
        if (corCaixa.isEmpty &&
            corAcab.isEmpty &&
            (project['valorCaixa'] == null) &&
            (project['valorAcab'] == null))
          _infoTile(Icons.info_outline, "Nenhuma especificação cadastrada", ""),
        if (corCaixa.isNotEmpty || project['valorCaixa'] != null)
          _moneyTile(
            Icons.inventory_2,
            corCaixa.isNotEmpty ? corCaixa : 'Não informada',
            "Cor da caixaria",
            project['valorCaixa'],
          ),
        if (corAcab.isNotEmpty || project['valorAcab'] != null)
          _moneyTile(
            Icons.brush,
            corAcab.isNotEmpty ? corAcab : 'Não informado',
            "Cor do acabamento",
            project['valorAcab'],
          ),
        if (extras.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle("Extras / adicionais"),
          ...extras.map((ex) {
            final Map exMap = ex as Map;
            final String nome = (exMap['nome'] ?? exMap['desc'] ?? 'Extra')
                .toString();
            return _moneyTile(Icons.add_box, nome, '', exMap['valor']);
          }),
        ],
        const SizedBox(height: 16),
        _sectionTitle("Valor total"),
        Container(
          decoration: BoxDecoration(
            color: panelSage,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: const Icon(Icons.attach_money, color: Colors.white),
            title: Text(
              "R\$ ${_formatMoney(project['valor'] ?? project['valorTotal'])}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            subtitle: const Text(
              "Valor do projeto",
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: panelSlate,
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: inkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hairline),
      ),
      child: ListTile(
        leading: Icon(icon, color: dellalioGold),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: panelIvory,
            fontSize: 14,
          ),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: TextStyle(color: panelSlateDim, fontSize: 11),
              )
            : null,
      ),
    );
  }

  Widget _moneyTile(
    IconData icon,
    String title,
    String subtitle,
    dynamic value,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: inkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hairline),
      ),
      child: ListTile(
        leading: Icon(icon, color: dellalioGold),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: panelIvory,
            fontSize: 14,
          ),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: TextStyle(color: panelSlateDim, fontSize: 11),
              )
            : null,
        trailing: Text(
          "R\$ ${_formatMoney(value)}",
          style: const TextStyle(fontWeight: FontWeight.bold, color: panelSage),
        ),
      ),
    );
  }

  Widget _buildGalleryTab(List<dynamic>? urls) {
    if (urls == null || urls.isEmpty)
      return const DellalioEmptyState(
        icon: Icons.photo_outlined,
        title: "Nenhuma foto",
      );
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: urls.length,
      itemBuilder: (ctx, i) {
        final String url = urls[i]?.toString() ?? '';
        if (url.isEmpty) return const SizedBox.shrink();
        return InkWell(
          onTap: () => showDialog(
            context: ctx,
            builder: (_) => Dialog(child: CachedNetworkImage(imageUrl: url)),
          ),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => Container(
              color: inkSurface,
              child: Icon(Icons.broken_image, color: panelSlate),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilesTab(List<dynamic>? files) {
    return PdfCoverGrid(items: files, emptyTitle: "Nenhum arquivo");
  }

  Widget _buildDocumentsTab(List<dynamic>? docs) {
    return PdfCoverGrid(items: docs, emptyTitle: "Nenhum documento");
  }
}
