import 'package:DELLALIO/screens/clientes/projects/criar_projeto.dart';
import 'package:DELLALIO/screens/clientes/projects/projectsview_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/user_session.dart';
class ViewClientScreen extends StatelessWidget {
  final String clientId;
  const ViewClientScreen({super.key, required this.clientId});

  Future<void> _deleteClient(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Excluir Cliente"),
      content: const Text("Tem certeza que deseja excluir este cliente permanentemente? Esta ação não pode ser desfeita."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true), 
          child: const Text("EXCLUIR", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (confirm == true) {
    // Fecha esta tela de detalhes IMEDIATAMENTE, antes de excluir no
    // Firestore. Assim, o StreamBuilder do documento do cliente nunca
    // chega a receber o evento de "documento removido" (data nulo),
    // pois a tela já não existe mais na árvore de widgets.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    try {
      final firestore = FirebaseFirestore.instance;
      final clientRef = firestore.collection('clients').doc(clientId);

      // Exclui também a subcoleção 'projects' do cliente antes de excluir
      // o documento pai, evitando dados órfãos no Firestore.
      final projectsSnap = await clientRef.collection('projects').get();

      // Exclui também todos os orçamentos vinculados a este cliente.
      // Orçamentos criados para um cliente já existente possuem o campo
      // 'clientId' (String) apontando para o ID do documento do cliente
      // (ver criarorcamento.dart). Buscamos todos esses orçamentos e suas
      // subcoleções 'projects' para não deixar dados órfãos no banco.
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
        final orcamentoProjectsSnap = await orcamentoDoc.reference.collection('projects').get();
        for (final projectDoc in orcamentoProjectsSnap.docs) {
          batch.delete(projectDoc.reference);
        }
        batch.delete(orcamentoDoc.reference);
      }

      await batch.commit();

      messenger.showSnackBar(const SnackBar(content: Text("Cliente excluído com sucesso!")));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Erro ao excluir: $e")));
    }
  }
}




  
@override
Widget build(BuildContext context) {




  
  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 123, 123, 123),
    // 1. Primeiro Stream: busca os dados do cliente (onde está o NOME)
    body: StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('clients').doc(clientId).snapshots(),
      builder: (context, clientSnapshot) {
        if (!clientSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // 'data' aqui contém os dados do cliente (name, phone, etc).
        // Se o documento foi excluído (ex: durante a navegação de saída
        // logo após a exclusão), data() retorna null. Nesse caso, não
        // tentamos fazer o cast (que quebraria a tela); simplesmente
        // mostramos um indicador de carregamento até a navegação de
        // saída (Navigator.pop) ser concluída.
        final rawData = clientSnapshot.data?.data();
        if (rawData == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = rawData as Map<String, dynamic>;


        // 2. Segundo Stream: busca os dados do projeto (onde estão fotos/arquivos)
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clients')
              .doc(clientId)
              .collection('projects')
              .snapshots(),
          builder: (context, projectSnapshot) {
            // Se o projeto ainda não existir, inicializa como vazio
            final projectData = (projectSnapshot.hasData && projectSnapshot.data!.docs.isNotEmpty)
                ? projectSnapshot.data!.docs.first.data() as Map<String, dynamic>
                : <String, dynamic>{};

            return DefaultTabController(
              length: 5,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    expandedHeight: 180,
                    pinned: true,
                    backgroundColor: const Color.fromARGB(255, 98, 80, 63),
                    flexibleSpace: FlexibleSpaceBar(
                      // Aqui usamos 'data' (do cliente) para o nome
                      title: Text((data['name'] ?? 'CLIENTE').toUpperCase(), 
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
                      color: Colors.white,
                      child: const TabBar(
                        labelColor: Colors.black,
                        indicatorColor: Color.fromARGB(255, 98, 80, 63),
                        tabs: [Tab(text: "DETALHES"), Tab(text: "PROJETOS"), Tab(text: "FOTOS"), Tab(text: "PDFS"),Tab(text: "DOCUMENTOS"),],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Aqui você pode usar 'data' para detalhes e 'projectData' para status/arquivos
                          _buildDetailsTab(context,data,projectData), 
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
  backgroundColor: const Color.fromARGB(255, 98, 80, 63),
  child: const Icon(Icons.add, color: Colors.white),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateProjectScreen(clientId: clientId),
      ),
    );
  },
),
  );
}
// ... dentro da sua ViewClientScreen ...

// O StreamBuilder de projetos agora lista TUDO da subcoleção para o seu Grid
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
      if (docs.isEmpty) return const Center(child: Text("Nenhum projeto registrado"));

      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.5, crossAxisSpacing: 16, mainAxisSpacing: 16,
        ),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final pData = docs[index].data() as Map<String, dynamic>;
          
          return Card(
            color: const Color(0xFF1E1E1E),
            child: InkWell(
              onTap: () {
                // Ao clicar, envia os dados para a tela de Detalhes do Projeto
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProjectDetailScreen(
                    projectId: docs[index].id,
                    clientId: clientId,
                  ),
                ));
              },
              child: Center(
                child: Text(
                  (pData['projectName'] ?? 'PROJETO').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    return const Center(child: Text("Nenhum documento anexado"));
  }
  
  return ListView.builder(
    padding: const EdgeInsets.all(20),
    itemCount: documentos.length,
    itemBuilder: (ctx, i) {
      final doc = documentos[i];
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(Icons.description, color: Colors.blueGrey),
          title: Text((doc as Map)['name'] ?? 'Documento sem nome'),
          trailing: const Icon(Icons.visibility),
          onTap: () {
            // Se for uma URL, abre no navegador
            if (doc['url'] != null) {
              launchUrl(Uri.parse(doc['url']), mode: LaunchMode.externalApplication);
            }
          },
        ),
      );
    },
  );
}


Widget _buildDetailsTab(BuildContext context,Map<String, dynamic> data, Map<String, dynamic> projectData) {
// 1. Extração e formatação da Data
  String formattedDate = '--/--';
  if (projectData.containsKey('deliveryDate') && projectData['deliveryDate'] != null) {
    final dynamic deliveryValue = projectData['deliveryDate'];
    
    // Se for Timestamp do Firebase
    if (deliveryValue is Timestamp) {
      DateTime date = deliveryValue.toDate();
      formattedDate = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } 
    // Se for uma String salva manualmente no banco
    else {
      formattedDate = deliveryValue.toString();
    }
  }

  // 2. Agora o 'formattedDate' contém o valor correto ou '--/--' caso esteja nulo

// final String status = projectData['status'] ?? 'PENDENTE';
  final String rawPhone = data['phone'] ?? '';
  final String formattedPhone = rawPhone.isNotEmpty 
      ? MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')}).maskText(rawPhone) 
      : '---';

  final String rawDoc = data['document'] ?? '';
  // Se for maior que 11, trata como CNPJ, caso contrário, CPF
  final String formattedDoc = rawDoc.isNotEmpty 
      ? MaskTextInputFormatter(
          mask: rawDoc.length > 11 ? '##.###.###/####-##' : '###.###.###-##', 
          filter: {"#": RegExp(r'[0-9]')}
        ).maskText(rawDoc)
      : '---';
    // Lista de itens para exibir na grade
    final List<Map<String, dynamic>> items = [
     {"label": "CPF / CNPJ", "value": formattedDoc, "icon": Icons.badge},
    {"label": "TELEFONE", "value": formattedPhone, "icon": Icons.phone}, {"label": "E-MAIL", "value": data['email'] ?? '---', "icon": Icons.email},
    //  {"label": "ENTREGA", "value": formattedDate, "icon": Icons.calendar_today},
           {"label": "ENDEREÇO", "value": data['address'] ?? 'Não informado', "icon": Icons.home},
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Reintroduzindo o Status aqui
//            Row(
//   children: [
//     Chip(
//       label: Text(status.toUpperCase(), 
//           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//       backgroundColor: (status == 'Concluído') ? Colors.green : Colors.orangeAccent,
//     ),
//   ],
// ),
            const SizedBox(height: 20),
              const SizedBox(height: 20),
            const Text("INFORMAÇÕES", style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold, color: Color.fromARGB(255, 17, 17, 17))),
            const SizedBox(height: 8),
           
            
            // Grid organizado
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Dois cards lado a lado
                childAspectRatio: 6, // Proporção para não ficar gigante
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                mainAxisExtent: 120,
          
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _infoCard(items[index]['label'], items[index]['value'], items[index]['icon']);
              },
            ),
            
            const SizedBox(height: 20),
            const Text("OBSERVAÇÕES", style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold, color: Color.fromARGB(255, 17, 17, 17))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
              child: Text(data['notes'] ?? 'Nenhuma observação.'),
            ),
            // ... dentro do ListView do _buildDetailsTab, após o Container das observações ...

const SizedBox(height: 40),
if (UserSession.isAdmin())
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: ElevatedButton.icon(
    onPressed: () => _deleteClient(context),
    icon: const Icon(Icons.delete_forever, color: Colors.white),
    label: const Text("EXCLUIR CLIENTE"),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.redAccent,
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
      color: Colors.white, 
      borderRadius: BorderRadius.circular(8), 
      border: Border.all(color: Colors.grey.shade200)
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Mantém o ícone no topo
      children: [
        Icon(icon, color: const Color.fromARGB(255, 98, 80, 63)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Faz a coluna ocupar apenas o necessário
            children: [
              Text(
                label, 
                style: const TextStyle(fontSize: 14, color: Color.fromARGB(255, 78, 78, 78))
              ),
              const SizedBox(height: 4),
              Text(
                value, 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                softWrap: true, // Permite quebrar a linha
                // Removido o overflow: TextOverflow.ellipsis para não cortar
              ),
            ],
          ),
        )
      ],
    ),
  );
}
Widget _buildGalleryTab(List<dynamic>? urls) {
  if (urls == null || urls.isEmpty) return const Center(child: Text("Nenhuma imagem"));
  return GridView.builder(
    padding: const EdgeInsets.all(20),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250, crossAxisSpacing: 15, mainAxisSpacing: 15),
    itemCount: urls.length,
    itemBuilder: (ctx, i) => InkWell(
      onTap: () => showDialog(context: ctx, builder: (_) => Dialog(child: CachedNetworkImage(imageUrl: urls[i]))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: urls[i],
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.grey[300]),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      ),
    ),
  );
}

  Widget _buildFilesTab(List<dynamic>? files) {
    if (files == null || files.isEmpty) return const Center(child: Text("Nenhum arquivo"));
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: files.length,
      itemBuilder: (ctx, i) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
          title: Text((files[i] as Map)['name'] ?? 'Arquivo'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => launchUrl(Uri.parse(files[i]['url']), mode: LaunchMode.externalApplication),
        ),
      ),

      
    );
  }

}
