import 'package:DELLALIO/screens/agenda/agenda_screen.dart';
import 'package:DELLALIO/screens/clientes/manageclients.dart';
import 'package:DELLALIO/screens/cronograma/cronograma_screen.dart';
import 'package:DELLALIO/screens/estoque/managestock.dart';
import 'package:DELLALIO/screens/lembretes/lembretes_screen.dart';
import 'package:DELLALIO/screens/login/meu_usuario_screen.dart';
import 'package:DELLALIO/screens/mensagens/mensagens.dart';
import 'package:DELLALIO/screens/orcamentos/menageorcamentos.dart';
import 'package:DELLALIO/screens/tarefas/tarefas_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../login/login_screen.dart';
import 'package:rxdart/rxdart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  void _navigateTo(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardContent(onNavigate: _navigateTo),
      const ManageStockScreen(),
      const RemindersScreen(),
      const ManageClientsListScreen(),
      const CronogramaScreen(),
      const MensagensScreen(),
      TarefasAdminScreen(),
      AgendaScreen(),
      ManageOrcamentosListScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          Material(
            color: const Color(0xFF0D0D0D),
            child: SizedBox(
              width: 240,
              child: Column(
                children: [
                  // Logo
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Image.asset('assets/imagens/logo/logo ld.png',
                        width: 150, fit: BoxFit.contain),
                  ),
                  const Divider(color: Colors.white24),

                  // Itens do menu
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildSidebarItem(Icons.dashboard, "Inicio", 0),
                          _buildSidebarItem(Icons.inventory_2, "Estoque", 1),
                          _buildSidebarItem(Icons.add_box, "Lembretes", 2),
                          _buildSidebarItem(Icons.people, "Clientes", 3),
                          _buildSidebarItem(Icons.timelapse, "Cronograma", 4),
                          _buildSidebarItem(Icons.message, "Mensagens", 5),
                          _buildSidebarItem(Icons.task, "Tarefas", 6),
                          _buildSidebarItem(Icons.calendar_today, "Agenda", 7),
                          _buildSidebarItem(Icons.work, "Orçamentos", 8),
                        ],
                      ),
                    ),
                  ),

                  // Rodapé
                  const Divider(color: Colors.white24),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                            child: _buildSidebarItem(Icons.person, "Perfil", 9)),
                        Expanded(
                            child: _buildSidebarItem(Icons.logout, "Sair", -1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon,
          color: _selectedIndex == index ? Colors.amber : Colors.white70),
      title: Text(title,
          style: TextStyle(
              color: _selectedIndex == index ? Colors.amber : Colors.white70)),
      onTap: () {
        if (index == -1) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        } else {
          _navigateTo(index);
        }
      },
    );
  }
}

class DashboardContent extends StatelessWidget {
  final Function(int) onNavigate;
  const DashboardContent({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    String? photoUrl = user?.photoURL;

    return Scaffold(
      appBar: AppBar(title: const Text("PAINEL DELLALIO")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .get(),
              builder: (context, snapshot) {
                String displayNome = "Usuário";
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  displayNome = data['nome'] ?? "Usuário";
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: photoUrl != null
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl == null
                                ? const Icon(Icons.person, size: 30)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Text("Bem-vindo, $displayNome".toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            _buildKPISection(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("PRIORIDADES DO DIA",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            _buildPriorityProjectsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildKPISection() {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clients').snapshots(),
      builder: (context, clientSnapshot) {
        final totalClientes =
            clientSnapshot.hasData ? clientSnapshot.data!.docs.length : 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('stock').snapshots(),
          builder: (context, stockSnapshot) {
            int estoqueCritico = 0;
            if (stockSnapshot.hasData) {
              for (var doc in stockSnapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                int q = data['quantity'] ?? 0;
                int m = data['minQuantity'] ?? 0;
                // Crítico: quantidade atual <= mínima + margem de 10
                if (q <= (m + 10)) {
                  estoqueCritico++;
                }
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('lembretes')
                  .snapshots(),
              builder: (context, reminderSnapshot) {
                final totalLembretes = reminderSnapshot.hasData
                    ? reminderSnapshot.data!.docs.length
                    : 0;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .where('participants', arrayContains: currentUid ?? '')
                      .snapshots(),
                  builder: (context, chatSnapshot) {
                    final totalChats = chatSnapshot.hasData
                        ? chatSnapshot.data!.docs.length
                        : 0;

                    // Conta conversas com mensagens não lidas
                    int chatsPendentes = 0;
                    if (chatSnapshot.hasData) {
                      for (var chatDoc in chatSnapshot.data!.docs) {
                        final data =
                            chatDoc.data() as Map<String, dynamic>;
                        final unread = data['unreadCount'] as int?;
                        if (unread != null && unread > 0) {
                          chatsPendentes++;
                        }
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _kpiCard("Total Clientes",
                                "$totalClientes", Colors.blue, () => onNavigate(3)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _kpiCard("Estoque Crítico",
                                "$estoqueCritico", Colors.red, () => onNavigate(1)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _kpiCard("Lembretes", "$totalLembretes",
                                Colors.orange, () => onNavigate(2)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _kpiCardComBadge(
                              "Mensagens",
                              "$totalChats",
                              Colors.green,
                              chatsPendentes,
                              () => onNavigate(5),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _kpiCard(
      String title, String value, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiCardComBadge(String title, String value, Color color,
      int pendingCount, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14)),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        "$pendingCount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityProjectsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clients').snapshots(),
      builder: (context, clientSnapshot) {
        if (!clientSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final clientDocs = clientSnapshot.data!.docs;
        final List<Stream<List<Map<String, dynamic>>>> projectStreams =
            clientDocs.map((clientDoc) {
          return clientDoc.reference
              .collection('projects')
              .where('status', isNotEqualTo: 'finalizado')
              .snapshots()
              .map((snap) => snap.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['clientName'] =
                        (clientDoc.data() as Map<String, dynamic>)['name']
                                ?.toString()
                                .toUpperCase() ??
                            'CLIENTE';
                    return data;
                  }).toList());
        }).toList();

        return StreamBuilder<List<List<Map<String, dynamic>>>>(
          stream: Rx.combineLatestList(projectStreams),
          builder: (context, projectSnapshot) {
            if (!projectSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            final allProjects =
                projectSnapshot.data!.expand((i) => i).toList();
            final validProjects = allProjects.where((data) {
              final date = data['deliveryDate'];
              return date != null && date is Timestamp;
            }).toList();

            validProjects.sort((a, b) {
              Timestamp t1 = a['deliveryDate'] as Timestamp;
              Timestamp t2 = b['deliveryDate'] as Timestamp;
              return t1.toDate().compareTo(t2.toDate());
            });

            final limitedProjects = validProjects.take(5).toList();

            if (limitedProjects.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Nenhuma prioridade pendente."),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: limitedProjects.length,
              itemBuilder: (context, index) {
                final data = limitedProjects[index];
                final date = (data['deliveryDate'] as Timestamp).toDate();
                final String dataFormatada =
                    "${date.day}/${date.month}/${date.year}";

                return Card(
                  elevation: 3,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['clientName'] ?? 'CLIENTE',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const Divider(),
                        Text(
                            data['projectName']
                                    ?.toString()
                                    .toUpperCase() ??
                                'PROJETO SEM NOME',
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Entrega: $dataFormatada".toUpperCase()),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                data['status']
                                        ?.toString()
                                        .toUpperCase() ??
                                    'N/A',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}