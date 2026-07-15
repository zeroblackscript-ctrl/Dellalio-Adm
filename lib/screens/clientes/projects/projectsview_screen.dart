import 'package:DELLALIO/screens/clientes/projects/editprojects_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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
        title: const Text('EXCLUIR PROJETO'),
        content: const Text(
            'Tem certeza que deseja excluir este projeto? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('EXCLUIR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      // Delete files from storage
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
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            final clientData =
                clientSnap.data!.data() as Map<String, dynamic>;
            final projectData =
                projectSnap.data!.data() as Map<String, dynamic>;

            return DefaultTabController(
              length: 4,
              child: Scaffold(
                backgroundColor: Colors.grey[200],
                appBar: AppBar(
                  title: Text((projectData['projectName'] ??
                          projectData['nome'])
                      ?.toString()
                      .toUpperCase() ??
                      "PROJETO"),
                  backgroundColor: const Color.fromARGB(255, 98, 80, 63),
                  bottom: const TabBar(
                    labelColor: Colors.white,
                    tabs: [
                      Tab(text: "INFO"),
                      Tab(text: "FOTOS"),
                      Tab(text: "PDFS"),
                      Tab(text: "CONTRATOS"),
                    ],
                  ),
                ),
                floatingActionButton: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isAdmin)
                      FloatingActionButton(
                        heroTag: 'delete',
                        backgroundColor: Colors.red,
                        mini: true,
                        child:
                            const Icon(Icons.delete, color: Colors.white),
                        onPressed: _deleteProject,
                      ),
                    if (_isAdmin) const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'edit',
                      backgroundColor:
                          const Color.fromARGB(255, 98, 80, 63),
                      child:
                          const Icon(Icons.edit, color: Colors.white),
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
                body: TabBarView(
                  children: [
                    _buildInfoTab(clientData, projectData),
                    _buildGalleryTab(projectData['galleryUrls']),
                    _buildFilesTab(projectData['files']),
                    _buildDocumentsTab(projectData['contratos']),
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
      Map<String, dynamic> client, Map<String, dynamic> project) {
    final String projectAddress =
        (project['address'] ?? '').toString().trim();
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
        _sectionTitle("DADOS DO CLIENTE"),
        Card(
            child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(
                    (client['name'] ?? '---').toString().toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Nome"))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.phone),
                title: Text(
                    (client['phone'] ?? '---').toString().toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Telefone"))),
        const SizedBox(height: 16),
        _sectionTitle("DADOS DA OBRA"),
        Card(
            child: ListTile(
                leading: const Icon(Icons.home),
                title: Text(address.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Endereço da Obra"))),
        if (cep.isNotEmpty)
          Card(
              child: ListTile(
                  leading: const Icon(Icons.markunread_mailbox),
                  title: Text(cep,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("CEP"))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.info),
                title: Text(
                    (project['status'] ?? 'PENDENTE')
                        .toString()
                        .toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Status do Projeto"))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(deliveryDate.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Entrega"))),
        if ((project['formaPagamento'] ?? '').toString().isNotEmpty)
          Card(
              child: ListTile(
                  leading: const Icon(Icons.payments),
                  title: Text(
                      project['formaPagamento']
                          .toString()
                          .toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Forma de Pagamento"))),
        if ((project['notes'] ?? '').toString().isNotEmpty)
          Card(
              child: ListTile(
                  leading: const Icon(Icons.notes),
                  title: Text(project['notes'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Observações"))),
        const SizedBox(height: 16),
        _sectionTitle("ESPECIFICAÇÕES TÉCNICAS"),
        if (corCaixa.isEmpty &&
            corAcab.isEmpty &&
            (project['valorCaixa'] == null) &&
            (project['valorAcab'] == null))
          const Card(
              child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text("Nenhuma especificação cadastrada"))),
        if (corCaixa.isNotEmpty || project['valorCaixa'] != null)
          Card(
            color: const Color(0xFFF3E9D2),
            child: ListTile(
              leading: const Icon(Icons.inventory_2,
                  color: Color.fromARGB(255, 98, 80, 63)),
              title: Text(
                  corCaixa.isNotEmpty
                      ? corCaixa.toUpperCase()
                      : 'NÃO INFORMADA',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Cor da Caixaria"),
              trailing: Text("R\$ ${_formatMoney(project['valorCaixa'])}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green)),
            ),
          ),
        if (corAcab.isNotEmpty || project['valorAcab'] != null)
          Card(
            color: const Color(0xFFF3E9D2),
            child: ListTile(
              leading: const Icon(Icons.brush,
                  color: Color.fromARGB(255, 98, 80, 63)),
              title: Text(
                  corAcab.isNotEmpty
                      ? corAcab.toUpperCase()
                      : 'NÃO INFORMADO',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Cor do Acabamento"),
              trailing: Text("R\$ ${_formatMoney(project['valorAcab'])}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green)),
            ),
          ),
        if (extras.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle("EXTRAS / ADICIONAIS"),
          ...extras.map((ex) {
            final Map exMap = ex as Map;
            final String nome =
                (exMap['nome'] ?? exMap['desc'] ?? 'Extra').toString();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.add_box, color: Colors.blueGrey),
                title: Text(nome.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text("R\$ ${_formatMoney(exMap['valor'])}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            );
          }),
        ],
        const SizedBox(height: 16),
        _sectionTitle("VALOR TOTAL"),
        Card(
          color: Colors.green[50],
          child: ListTile(
            leading: const Icon(Icons.attach_money, color: Colors.green),
            title: Text(
              "R\$ ${_formatMoney(project['valor'] ?? project['valorTotal'])}",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.green),
            ),
            subtitle: const Text("Valor do Projeto"),
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
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color.fromARGB(255, 98, 80, 63)),
      ),
    );
  }

  Widget _buildGalleryTab(List<dynamic>? urls) {
    if (urls == null || urls.isEmpty)
      return const Center(child: Text("Nenhuma foto"));
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: urls.length,
      itemBuilder: (ctx, i) {
        final String url = urls[i]?.toString() ?? '';
        if (url.isEmpty) return const SizedBox.shrink();
        return InkWell(
          onTap: () => showDialog(
              context: ctx,
              builder: (_) =>
                  Dialog(child: CachedNetworkImage(imageUrl: url))),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image)),
          ),
        );
      },
    );
  }

  Widget _buildFilesTab(List<dynamic>? files) {
    if (files == null || files.isEmpty)
      return const Center(child: Text("Nenhum arquivo"));
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (ctx, i) {
        final dynamic raw = files[i];
        final String name =
            (raw is Map) ? (raw['name']?.toString() ?? 'Arquivo') : 'Arquivo';
        final String? url = (raw is Map) ? raw['url']?.toString() : null;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: Text(name.toUpperCase()),
            onTap: url == null
                ? null
                : () => launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication),
          ),
        );
      },
    );
  }

  Widget _buildDocumentsTab(List<dynamic>? docs) {
    if (docs == null || docs.isEmpty)
      return const Center(child: Text("Nenhum documento"));
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final dynamic raw = docs[i];
        final String name = (raw is Map)
            ? (raw['name']?.toString() ?? 'Documento')
            : 'Documento';
        final String? url = (raw is Map) ? raw['url']?.toString() : null;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.description, color: Colors.blueGrey),
            title: Text(name.toUpperCase()),
            onTap: url == null
                ? null
                : () => launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication),
          ),
        );
      },
    );
  }
}