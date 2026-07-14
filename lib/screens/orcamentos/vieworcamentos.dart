import 'package:DELLALIO/screens/orcamentos/editor_ambientes.dart';
import 'package:DELLALIO/screens/orcamentos/novo_rascunho.dart';
import 'package:DELLALIO/screens/orcamentos/rascunhos.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class ViewBudgetScreen extends StatelessWidget {
  final String orcamentoId;

  const ViewBudgetScreen({super.key, required this.orcamentoId});




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 123, 123, 123),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orcamentos').doc(orcamentoId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Se o orçamento foi excluído (documento removido), o Firestore
          // emite um evento com data() nulo antes da navegação de saída
          // ser concluída. Evitamos o crash mostrando um loading nesse caso.
          final rawData = snapshot.data?.data();
          if (rawData == null) {
            return const Scaffold(
              backgroundColor: Color.fromARGB(255, 123, 123, 123),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final data = rawData as Map<String, dynamic>;


          // Retornamos um Scaffold único aqui para garantir que a barra inferior 
          // tenha acesso à variável 'data'
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 123, 123, 123),
            body: DefaultTabController(
              length: 2,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    expandedHeight: 180,
                    pinned: true,
                    backgroundColor: const Color.fromARGB(255, 98, 80, 63),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.white),
                        tooltip: "Excluir Orçamento",
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
                      color: Colors.white,
                      child: const TabBar(
                        labelColor: Colors.black,
                        indicatorColor: Color.fromARGB(255, 98, 80, 63),
                        tabs: [Tab(text: "DETALHES"), Tab(text: "PROJETOS/RASCUNHOS")],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildDetailsTab(data),
                         StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orcamentos')
            .doc(orcamentoId)
            .collection('projects')
            .snapshots(),
        builder: (context, projectSnapshot) {
          if (!projectSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          // Transforma os documentos da subcoleção em uma lista de Map
          final listaProjetos = projectSnapshot.data!.docs
              .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
              .toList();

          return _buildProjectsGrid(listaProjetos);
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
              unselectedItemColor: Colors.white,
              backgroundColor: const Color.fromARGB(255, 19, 19, 19),
              selectedItemColor: Colors.white,
              onTap: (index) {
                if (index == 0) {
                  // Navegação para configurar ambiente
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ConfigurarAmbienteScreen(orcamentoId: orcamentoId)
                  ));
                } else if (index == 1) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ListarRascunhosScreen(orcamentoId: orcamentoId)));
                } else if (index == 2) {
                  // Aqui 'data' é reconhecido perfeitamente!
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

  // Exclui o orçamento e todos os projetos da subcoleção 'projects',
  // garantindo que nenhum dado órfão fique no banco.
  void _showDeleteOrcamentoDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Orçamento"),
        content: const Text(
          "Tem certeza que deseja excluir este orçamento? Todos os projetos vinculados a ele também serão removidos permanentemente. Esta ação não pode ser desfeita.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              // Fecha o diálogo e a tela de detalhes IMEDIATAMENTE, antes
              // de excluir no Firestore. Assim o StreamBuilder do documento
              // do orçamento nunca chega a receber o evento de "documento
              // removido" (data nulo), pois a tela já não existe mais.
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx); // Fecha o dialog
              Navigator.pop(context); // Volta para a lista de orçamentos

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
            child: const Text("Sim, excluir"),
          ),

        ],
      ),
    );
  }

 void _showFinalizarDialog(BuildContext context, String id, Map<String, dynamic> cData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Finalizar Orçamento"),
        content: const Text("Converter orçamento em cliente ativo e migrar todos os projetos com suas especificações?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                final db = FirebaseFirestore.instance;
                final orcamentoDoc = db.collection('orcamentos').doc(id);
                final projectsSnapshot = await orcamentoDoc.collection('projects').get();

                final batch = db.batch();

                // Se o orçamento já possui um clientId vinculado (foi criado
                // a partir de "Projeto p/ Cliente Existente"), reutilizamos
                // o cliente já existente ao invés de criar um novo, evitando
                // duplicar clientes. Só criamos um novo cliente quando o
                // orçamento não tiver nenhum cliente vinculado.
                final String? existingClientId = cData['clientId'] as String?;
                final bool usaClienteExistente = existingClientId != null && existingClientId.isNotEmpty;

                final DocumentReference clienteRef = usaClienteExistente
                    ? db.collection('clients').doc(existingClientId)
                    : db.collection('clients').doc();

                if (!usaClienteExistente) {
                  // 1. CRIA O NOVO CLIENTE (Copiando TUDO do orçamento original)
                  // Pega todos os dados (name, phone, address, totalGeral, etc)
                  final Map<String, dynamic> novoClienteData = Map<String, dynamic>.from(cData);
                  // Atualizamos a data para o momento da aprovação do cliente
                  novoClienteData['createdAt'] = FieldValue.serverTimestamp();

                  batch.set(clienteRef, novoClienteData);
                }
                // Se usaClienteExistente == true, não mexemos no documento do
                // cliente: ele já existe e mantém seus próprios dados.

                // 2. MIGRA OS PROJETOS DO ORÇAMENTO PARA O CLIENTE
                for (var doc in projectsSnapshot.docs) {
                  // doc.data() pega LITERALMENTE TUDO: corAcab, corCaixa, valorTotal, extras, etc.
                  final projetoOriginalData = doc.data();
                  
                  // ADICIONAMOS as chaves de controle que a tela de Projetos do Cliente usa,
                  // sem apagar NADA do que veio do orçamento.
                  projetoOriginalData['status'] = 'conferencia'; // Status inicial padrão
                  projetoOriginalData['files'] = projetoOriginalData['files'] ?? []; // Arrays vazios p/ grid
                  projetoOriginalData['galleryUrls'] = projetoOriginalData['galleryUrls'] ?? [];
                  
                  // Compatibilidade: garante que a tela de projetos ache o "nome" e o "valor"
                  // independentemente se foi salvo como 'nome' ou 'projectName' no orçamento
                  projetoOriginalData['projectName'] = projetoOriginalData['nome'] ?? 'Projeto Importado';
                  projetoOriginalData['valor'] = projetoOriginalData['valorTotal'] ?? 0.0;
                  projetoOriginalData['environment'] = projetoOriginalData['nome'] ?? 'Outro';

                  // Salva na subcoleção 'projects' do cliente (novo ou já existente),
                  // gerando um novo ID quando o cliente já existir, para não sobrescrever
                  // acidentalmente projetos que já possam ter o mesmo ID.
                  final novoProjetoRef = usaClienteExistente
                      ? clienteRef.collection('projects').doc()
                      : clienteRef.collection('projects').doc(doc.id);
                  batch.set(novoProjetoRef, projetoOriginalData);
                  
                  // Deleta o projeto original da coleção de orçamentos
                  batch.delete(doc.reference);
                }

                // 3. Deleta o documento pai do orçamento original
                batch.delete(orcamentoDoc);

                // 4. Dispara todas as ações no servidor simultaneamente
                await batch.commit();

                if (context.mounted) {
                  Navigator.pop(ctx); 
                  Navigator.pop(context); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Cliente ativado e todos os dados migrados com sucesso!"),
                      backgroundColor: Colors.green,
                    )
                  );
                }
              } catch (e) {
                debugPrint("Erro: $e");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erro ao finalizar: $e", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red)
                  );
                }
              }
            },
            child: const Text("Confirmar"),
          )
        ],
      ),
    );
  }

  Widget _buildDetailsTab(Map<String, dynamic> data) {
    final rawPhone = data['phone'] ?? '';
    final formattedPhone = rawPhone.isNotEmpty 
        ? MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')}).maskText(rawPhone) 
        : '---';

    final List<Map<String, dynamic>> items = [
      {"label": "NOME", "value": data['name'].toString().toUpperCase(), "icon": Icons.person},
      {"label": "TELEFONE", "value": formattedPhone, "icon": Icons.phone},
      {"label": "ENDEREÇO", "value": data['address'] != null ? data['address'].toString().toUpperCase() : 'Não informado', "icon": Icons.home},
      {"label": "TOTAL GERAL", "value": "R\$ ${data['totalGeral']?.toStringAsFixed(2) ?? '0,00'}", "icon": Icons.attach_money},
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("INFORMAÇÕES DO ORÇAMENTO", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 4,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _infoCard(items[index]['label'], items[index]['value'], items[index]['icon']),
        ),
      ],
    );
  }

Widget _buildProjectsGrid(List<Map<String, dynamic>> projetos) {
if (projetos.isEmpty) return const Center(child: Text("Nenhum projeto registrado", style: TextStyle(color: Colors.white)));    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, childAspectRatio: 4, crossAxisSpacing: 22, mainAxisSpacing: 5,
      ),
      itemCount: projetos.length,
    itemBuilder: (context, index) {
      final pData = projetos[index];
      return Card(
        color: const Color(0xFF1E1E1E),
        child: InkWell(
          onTap: () async {
  final alterou = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EditorAmbienteScreen(
        
        orcamentoId: orcamentoId, projeto: pData, // Passe o ID correto aqui
      ),
    ),
  );
  
  if (alterou == true) {
    // Aqui você chama seu método para recarregar a lista do Firestore
    // ex: _carregarDados();
  }
},
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text((pData['nome'] ?? 'PROJETO').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text("R\$ ${pData['valorTotal']?.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: const Color.fromARGB(255, 98, 80, 63)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
