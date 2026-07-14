import 'package:DELLALIO/screens/orcamentos/criarorcamento.dart';
import 'package:DELLALIO/screens/orcamentos/editorcamento.dart';
import 'package:DELLALIO/screens/orcamentos/vieworcamentos.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageOrcamentosListScreen extends StatefulWidget {
  const ManageOrcamentosListScreen({super.key});

  @override
  State<ManageOrcamentosListScreen> createState() => _ManageOrcamentosListScreenState();
}

class _ManageOrcamentosListScreenState extends State<ManageOrcamentosListScreen> {
  String _searchQuery = "";

  void _showSelectClientDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Selecione o Cliente"),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('clients').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final clients = snapshot.data!.docs;
              
              return ListView.builder(
                itemCount: clients.length,
                itemBuilder: (context, index) {
                  final clientData = clients[index].data() as Map<String, dynamic>;
                  final clientId = clients[index].id;
                  
                  return ListTile(
                    title: Text(clientData['name'] ?? 'Sem nome'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context); // Fecha o diálogo
                      // Navega para a tela de criação passando o clientId
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateFullClientAndBudgetScreen(preselectedClientId: clientId),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: "Buscar orçamento",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent, 
                  fixedSize: const Size(160, 50),
                  foregroundColor: Colors.white
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateFullClientAndBudgetScreen())),
                child: const Text('Novo Orçamento', style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              SizedBox(
                width: 30,
              ),

              ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.green, 
    fixedSize: const Size(180, 50),
    foregroundColor: Colors.white
  ),
  onPressed: () => _showSelectClientDialog(context),
  child: const Text('Projeto p/ Cliente\nExistente', 
      textAlign: TextAlign.center, 
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orcamentos').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Nenhum orçamento encontrado."));
              }
              
              var docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['name']?.toString().toLowerCase().contains(_searchQuery) ?? false;
              }).toList();

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, childAspectRatio: 1.5, crossAxisSpacing: 16, mainAxisSpacing: 16,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) => _buildOrcamentoCard(context, docs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  
Widget _buildOrcamentoCard(BuildContext context, DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  
  return Card(
    elevation: 4,
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ViewBudgetScreen(orcamentoId: doc.id)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['name']?.toString().toUpperCase() ?? "SEM NOME",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      SizedBox(height: 20,),
                  
                  // // AQUI BUSCAMOS O NOME DO PROJETO
                  // StreamBuilder<QuerySnapshot>(
                  //   stream: doc.reference.collection('projects').limit(1).snapshots(),
                  //   builder: (context, projSnap) {
                  //     if (!projSnap.hasData || projSnap.data!.docs.isEmpty) {
                  //       return const Text("Sem projetos", style: TextStyle(fontSize: 12, color: Colors.grey));
                  //     }
                  //     final projData = projSnap.data!.docs.first.data() as Map<String, dynamic>;
                  //     return Text(
                  //       "Projeto: ${projData['projectName']
                  //        ?? 'Sem nome'}",
                  //       style: const TextStyle(fontSize: 16,fontWeight: FontWeight.bold),
                  //       overflow: TextOverflow.ellipsis,
                  //     );
                  //   },
                  // ),
                ],
              ),
            ),
          ),
          
          // Botão Editar
          Container(
            height: 45,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFD4AF37),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => Editorcamento(orcamentoId: doc.id)),
              ),
              icon: const Icon(Icons.edit, color: Colors.white, size: 18),
              label: const Text("EDITAR ORÇAMENTO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ),
  );
}

}