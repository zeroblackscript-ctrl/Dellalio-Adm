import 'package:DELLALIO/screens/clientes/editclients.dart';
import 'package:DELLALIO/screens/clientes/register_client_screen.dart';
import 'package:DELLALIO/screens/clientes/viewscreen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';

class ManageClientsListScreen extends StatefulWidget {
  const ManageClientsListScreen({super.key});

  @override
  State<ManageClientsListScreen> createState() => _ManageClientsListScreenState();
}

class _ManageClientsListScreenState extends State<ManageClientsListScreen> {
  String _searchQuery = "";

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pedido':
        return Colors.blue;
      case 'conferencia':
        return Colors.purple;
      case 'producao':
        return Colors.amber;
      case 'montagem':
        return Colors.orange;
      case 'entrega':
        return Colors.teal;
      case 'finalizado':
        return Colors.red;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? DellalioTheme.darkBackground : DellalioTheme.lightBackground;
    final cardBg = isDark ? const Color(0xFF0D0D0D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      color: bgColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: "BUSCAR CLIENTE",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    fixedSize: const Size(150, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterClientScreen()),
                  ),
                  child: const Text('NOVO CLIENTE',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('clients').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['name']?.toString().toLowerCase().contains(_searchQuery) ?? false;
                }).toList();

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
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildClientGridCard(context, docs[index].id, data, cardBg, textColor, subtitleColor, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientGridCard(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    bool isDark,
  ) {
    return Card(
      color: cardBg,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
                (data['name'] ?? 'SEM NOME').toUpperCase(),
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
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
                    return Text("CARREGANDO...", style: TextStyle(color: subtitleColor));
                  }
                  final projects = projectSnapshot.data!.docs;
                  if (projects.isEmpty) {
                    return Text("SEM PROJETOS", style: TextStyle(color: subtitleColor));
                  }
                  final pData = projects.first.data() as Map<String, dynamic>;
                  final status = pData['status'] ?? 'vendas';
                  return Text(
                    "STATUS: ${status.toUpperCase()}",
                    style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold),
                  );
                },
              ),
              const Spacer(),
              Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade300),
              Container(
                width: double.infinity,
                height: 45,
                decoration: BoxDecoration(
                  color: petroleoColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditClientScreen(clientId: id)),
                  ),
                  icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                  label: const Text("EDITAR CLIENTE",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}