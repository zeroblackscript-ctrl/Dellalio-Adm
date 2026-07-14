import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CronogramaScreen extends StatefulWidget {
  const CronogramaScreen({super.key});

  @override
  State<CronogramaScreen> createState() => _CronogramaScreenState();
}

class _CronogramaScreenState extends State<CronogramaScreen> with SingleTickerProviderStateMixin {
  final List<String> statusSteps = const ['conferencia', 'pedido', 'producao', 'entrega', 'montagem', 'finalizado'];
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 240, 240), // Cor mais clara para melhor contraste
      appBar: AppBar(title: const Text("CRONOGRAMA DE PRODUÇÃO")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clients').snapshots(),
        builder: (context, clientSnapshot) {
          if (!clientSnapshot.hasData) return const Center(child: CircularProgressIndicator());

          final clientDocs = clientSnapshot.data!.docs;

          // Criamos um FutureBuilder para processar a união de projetos de forma limpa
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchAllProjects(clientDocs),
            builder: (context, projectSnapshot) {
              if (!projectSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final projetos = projectSnapshot.data!;
              if (projetos.isEmpty) return const Center(child: Text("Nenhum projeto pendente."));

              return ListView.builder(
                padding: const EdgeInsets.only(top: 10),
                itemCount: projetos.length,
                itemBuilder: (context, index) {
                  final pData = projetos[index];
                  var dataEntrega = (pData['deliveryDate'] as Timestamp?)?.toDate();
                  String statusAtual = pData['status'] ?? 'producao';
                  
                  int diasRestantes = dataEntrega != null ? dataEntrega.difference(DateTime.now()).inDays : 0;
                  String textoDias = diasRestantes < 0 ? "Atrasado" : "$diasRestantes dias para entrega";

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(pData['projectName']?.toUpperCase() ?? 'SEM NOME', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Cliente: ${pData['clientName']}"),
                                Text(textoDias, style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  color: diasRestantes <= 3 ? Colors.red : Colors.green.shade700
                                )),
                              ],
                            ),
                          ),
                          const Divider(),
                          _buildTimeline(statusAtual),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Método que busca todos os projetos ativos de todos os clientes
  Future<List<Map<String, dynamic>>> _fetchAllProjects(List<QueryDocumentSnapshot> clientDocs) async {
    List<Map<String, dynamic>> allProjects = [];

    for (var client in clientDocs) {
      final projects = await client.reference.collection('projects')
          .where('status', isNotEqualTo: 'finalizado')
          .get();

      for (var doc in projects.docs) {
        final data = doc.data();
        data['clientName'] = (client.data() as Map<String, dynamic>)['name'] ?? 'Cliente';
        allProjects.add(data);
      }
    }
    // Ordena por data de entrega
    allProjects.sort((a, b) => (a['deliveryDate'] as Timestamp? ?? Timestamp.now())
        .compareTo(b['deliveryDate'] as Timestamp? ?? Timestamp.now()));
    
    return allProjects;
  }

  Widget _buildTimeline(String currentStatus) {
    // ... (Seu código original do _buildTimeline continua funcionando perfeitamente)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: statusSteps.asMap().entries.map((entry) {
        int idx = entry.key;
        String step = entry.value;
        bool isCurrent = step == currentStatus;
        bool isReached = statusSteps.indexOf(step) <= statusSteps.indexOf(currentStatus);
        
        return Row(
          children: [
            Column(
              children: [
                isCurrent 
                  ? FadeTransition(opacity: _controller, child: const Icon(Icons.circle, size: 24, color: Colors.brown))
                  : Icon(Icons.circle, size: 20, color: isReached ? Colors.brown : Colors.grey.shade300),
                const SizedBox(height: 5),
                Text(step.toUpperCase(), style: TextStyle(fontSize: 8, color: isReached ? Colors.brown : Colors.grey)),
              ],
            ),
            if (idx < statusSteps.length - 1) 
              Container(width: 30, height: 2, color: statusSteps.indexOf(step) < statusSteps.indexOf(currentStatus) ? Colors.brown : Colors.grey.shade300),
          ],
        );
      }).toList(),
    );
  }
}