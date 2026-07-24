import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';

class CronogramaScreen extends StatefulWidget {
  const CronogramaScreen({super.key});

  @override
  State<CronogramaScreen> createState() => _CronogramaScreenState();
}

class _CronogramaScreenState extends State<CronogramaScreen> with SingleTickerProviderStateMixin {
  final List<String> statusSteps = const [
    'CONFERÊNCIA', 'PEDIDO', 'PRODUÇÃO', 'ENTREGA', 'MONTAGEM', 'FINALIZADO'
  ];
  static const List<String> statusKeys = const [
    'conferencia', 'pedido', 'producao', 'entrega', 'montagem', 'finalizado'
  ];
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

  int _statusIndex(String status) {
    final idx = statusKeys.indexOf(status);
    return idx >= 0 ? idx : 2; // fallback 'producao'
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? DellalioTheme.darkBackground : const Color(0xFFF0F2F5);
    final cardColor = isDark ? DellalioTheme.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;
    final stepColor = isDark ? petroleoLightColor : petroleoColor;
    final unreachedColor = isDark ? Colors.white24 : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("CRONOGRAMA DE PRODUÇÃO"),
        backgroundColor: petroleoColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clients').snapshots(),
        builder: (context, clientSnapshot) {
          if (!clientSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final clientDocs = clientSnapshot.data!.docs;

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchAllProjects(clientDocs),
            builder: (context, projectSnapshot) {
              if (!projectSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final projetos = projectSnapshot.data!;
              if (projetos.isEmpty) {
                return Center(
                  child: Text(
                    "NENHUM PROJETO PENDENTE",
                    style: TextStyle(color: subtitleColor, fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 10),
                itemCount: projetos.length,
                itemBuilder: (context, index) {
                  final pData = projetos[index];
                  var dataEntrega =
                      (pData['deliveryDate'] as Timestamp?)?.toDate();
                  String statusAtual = pData['status'] ?? 'producao';

                  int diasRestantes = dataEntrega != null
                      ? dataEntrega.difference(DateTime.now()).inDays
                      : 0;
                  String textoDias = diasRestantes < 0
                      ? "ATRASADO"
                      : "$diasRestantes DIAS PARA ENTREGA";

                  final Color diasColor = diasRestantes <= 3
                      ? Colors.red
                      : isDark
                          ? Colors.greenAccent
                          : Colors.green.shade700;

                  return Card(
                    color: cardColor,
                    elevation: 4,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              pData['projectName']?.toUpperCase() ?? 'SEM NOME',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: textColor),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "CLIENTE: ${pData['clientName']}",
                                  style: TextStyle(color: subtitleColor),
                                ),
                                Text(
                                  textoDias,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: diasColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(color: isDark ? Colors.white12 : Colors.grey.shade200),
                          _buildTimeline(statusAtual, stepColor, unreachedColor, isDark),
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

  Future<List<Map<String, dynamic>>> _fetchAllProjects(
      List<QueryDocumentSnapshot> clientDocs) async {
    List<Map<String, dynamic>> allProjects = [];

    for (var client in clientDocs) {
      final projects = await client.reference
          .collection('projects')
          .where('status', isNotEqualTo: 'finalizado')
          .get();

      for (var doc in projects.docs) {
        final data = doc.data();
        data['clientName'] =
            (client.data() as Map<String, dynamic>)['name'] ?? 'CLIENTE';
        allProjects.add(data);
      }
    }
    allProjects.sort((a, b) =>
        (a['deliveryDate'] as Timestamp? ?? Timestamp.now())
            .compareTo(b['deliveryDate'] as Timestamp? ?? Timestamp.now()));

    return allProjects;
  }

  Widget _buildTimeline(String currentStatus, Color stepColor, Color unreachedColor, bool isDark) {
    final currentIdx = _statusIndex(currentStatus);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(statusSteps.length, (idx) {
        final step = statusSteps[idx];
        final isCurrent = idx == currentIdx;
        final isReached = idx <= currentIdx;

        return Row(
          children: [
            Column(
              children: [
                if (isCurrent)
                  FadeTransition(
                    opacity: _controller,
                    child: Icon(Icons.circle, size: 24, color: stepColor),
                  )
                else
                  Icon(Icons.circle,
                      size: 20,
                      color: isReached ? stepColor : unreachedColor),
                const SizedBox(height: 5),
                Text(
                  step,
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: isReached
                        ? (isDark ? Colors.white : stepColor)
                        : (isDark ? Colors.white38 : Colors.grey),
                  ),
                ),
              ],
            ),
            if (idx < statusSteps.length - 1)
              Container(
                width: 22,
                height: 2,
                color: idx < currentIdx
                    ? stepColor
                    : unreachedColor,
              ),
          ],
        );
      }),
    );
  }
}