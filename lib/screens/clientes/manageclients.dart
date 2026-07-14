
import 'package:DELLALIO/screens/clientes/editclients.dart';
import 'package:DELLALIO/screens/clientes/register_client_screen.dart';
import 'package:DELLALIO/screens/clientes/viewscreen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      return Colors.blue;      // Azul para início
    case 'conferencia':
      return Colors.purple;    // Roxo para conferência
    case 'producao':
      return Colors.amber;     // Amarelo para produção
    case 'montagem':
      return Colors.orange;    // Laranja para montagem
    case 'entrega':
      return Colors.teal;      // Verde-água para entrega
    case 'finalizado':
      return Colors.red;      // Cinza para concluído
    default:
      return Colors.white70;   // Cor padrão
  }
}

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. TOPO: Busca e Adicionar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: "Buscar cliente",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.toLowerCase()),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                child: Text(
                  'Novo Cliente',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegisterClientScreen(),
                  ),
                ),

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  fixedSize: const Size(150, 50),
                  // Define o formato como um retângulo com cantos levemente arredondados
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. CORPO: Grid de Clientes
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('clients')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['name']?.toString().toLowerCase().contains(
                      _searchQuery,
                    ) ??
                    false;
              }).toList();

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // Quantidade de cards por linha
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return _buildClientGridCard(context, docs[index].id, data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Card individual do Grid
  Widget _buildClientGridCard(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ViewClientScreen(clientId: id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (data['name'] ?? 'Sem nome').toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
             StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('clients')
                      .doc(id)
                      .collection('projects')
                      .snapshots(),
                  builder: (context, projectSnapshot) {
                    if (!projectSnapshot.hasData) {
                      return const Text("Carregando...", style: TextStyle(color: Colors.white70));
                    }
                    
                    // Pega o primeiro projeto da lista (ou trate como necessário)
                    final projects = projectSnapshot.data!.docs;
                    if (projects.isEmpty) return const Text("Sem projetos", style: TextStyle(color: Colors.white70));
                    
                    final pData = projects.first.data() as Map<String, dynamic>;
                    final status = pData['status'] ?? 'vendas';
                    
                    return Text(
                      "Status: ${status.toUpperCase()}",
                      style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold),
                    );
                  },
                ),
              const Spacer(),
              const Divider(
                height: 1,
                color: Colors.white24,
              ), // Ajuste o divisor para ficar mais fino
              Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  color: Color(0xFFD4AF37),
                ),

                width: double
                    .infinity, // Faz o container ocupar toda a largura do Card
                height: 45, // Altura definida para o botão
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditClientScreen(clientId: id),
                    ),
                  ),
                  icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                  label: const Text(
                    "EDITAR CLIENTE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
