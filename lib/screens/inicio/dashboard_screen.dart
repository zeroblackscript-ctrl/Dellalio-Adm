import 'dart:async';

import 'package:DELLALIO/screens/agenda/agenda_screen.dart';
import 'package:DELLALIO/screens/clientes/manageclients.dart';
import 'package:DELLALIO/screens/cronograma/cronograma_screen.dart';
import 'package:DELLALIO/screens/estoque/managestock.dart';
import 'package:DELLALIO/screens/lembretes/lembretes_screen.dart';
import 'package:DELLALIO/screens/login/meu_usuario_screen.dart';
import 'package:DELLALIO/screens/mensagens/mensagens.dart';
import 'package:DELLALIO/screens/orcamentos/menageorcamentos.dart';
import 'package:DELLALIO/screens/tarefas/tarefas_screen.dart';
import 'package:auto_updater/auto_updater.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/theme.dart';
import '../../core/user_session.dart';
import '../login/login_screen.dart';

/// Versão atual do aplicativo (extraída do pubspec.yaml)
const String kAppVersion = '1.4.8';

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

  static const List<_NavEntry> _navEntries = [
    _NavEntry(Icons.dashboard_outlined, "Início", 0),
    _NavEntry(Icons.inventory_2_outlined, "Estoque", 1),
    _NavEntry(Icons.notifications_outlined, "Lembretes", 2),
    _NavEntry(Icons.people_outline, "Clientes", 3),
    _NavEntry(Icons.timelapse_outlined, "Cronograma", 4),
    _NavEntry(Icons.chat_bubble_outline, "Mensagens", 5),
    _NavEntry(Icons.task_alt_outlined, "Tarefas", 6),
    _NavEntry(Icons.calendar_today_outlined, "Agenda", 7),
    _NavEntry(Icons.work_outline, "Orçamentos", 8),
  ];

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardContent(onNavigate: _navigateTo),
      ManageStockScreen(),
      RemindersScreen(),
      ManageClientsListScreen(),
      CronogramaScreen(),
      MensagensScreen(),
      TarefasAdminScreen(),
      AgendaScreen(),
      ManageOrcamentosListScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: inkPageBg,
      body: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: Container(
              width: 236,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [inkSurfaceHover, inkPageBg],
                  stops: const [0.0, 0.85],
                ),
                border: Border(right: BorderSide(color: hairline)),
              ),
              child: Column(
                children: [
                  // Marca
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    child: Row(
                      children: [
                        Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: dellalioGold,
                                  width: 1.4,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/imagens/logo/logo ld.png',
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .custom(
                              duration: 2200.ms,
                              builder: (context, value, child) => Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: dellalioGold.withValues(
                                        alpha: 0.06 * value,
                                      ),
                                      blurRadius: 6,
                                      spreadRadius: 4 * value,
                                    ),
                                  ],
                                ),
                                child: child,
                              ),
                            ),
                        const SizedBox(width: 11),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dellalio',
                              style: TextStyle(
                                fontFamily: 'Fraunces',
                                fontSize: 14.5,
                                letterSpacing: 0.4,
                                color: panelIvory,
                              ),
                            ),
                            Text(
                              'CÉREBRO',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.2,
                                color: panelSlateDim,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(color: hairline, height: 1),

                  // Itens do menu
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Column(
                          children: [
                            for (final entry in _navEntries)
                              _buildSidebarItem(entry),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Rodapé
                  Divider(color: hairline, height: 1),
                  _buildThemeToggle(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSidebarItem(
                            const _NavEntry(Icons.person_outline, "Perfil", 9),
                          ),
                        ),
                        Expanded(
                          child: _buildSidebarItem(
                            const _NavEntry(Icons.logout, "Sair", -1),
                          ),
                        ),
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

  Widget _buildThemeToggle() {
    final isDark = UserSession.isDarkMode();
    return ListTile(
      dense: true,
      leading: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        size: 16,
        color: panelSlateDim,
      ),
      title: Text(
        isDark ? 'Modo claro' : 'Modo escuro',
        style: TextStyle(color: panelSlateDim, fontSize: 11.5),
      ),
      onTap: () async {
        await UserSession.toggleDarkMode();
        ThemeNotifier.instance.toggle();
        setState(() {});
      },
    );
  }

  Widget _buildSidebarItem(_NavEntry entry) {
    final bool isActive = _selectedIndex == entry.index;
    final int staggerIndex = entry.index < 0 ? 0 : entry.index;
    return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isActive
                ? dellalioGold.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isActive ? dellalioGold : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              leading: entry.index == 9
                  ? _buildProfileAvatar(isActive)
                  : Icon(
                      entry.icon,
                      size: 18,
                      color: isActive ? dellalioGoldSoft : panelSlate,
                    ),
              title: Text(
                entry.label,
                style: TextStyle(
                  fontSize: 13,
                  color: isActive ? dellalioGoldSoft : panelSlate,
                ),
              ),
              onTap: () {
                if (entry.index == -1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                } else {
                  _navigateTo(entry.index);
                }
              },
            ),
          ),
        )
        .animate(delay: (60 * staggerIndex).ms)
        .fadeIn(duration: 320.ms)
        .slideX(begin: -0.06, end: 0, curve: Curves.easeOut);
  }

  Widget _buildProfileAvatar(bool isActive) {
    final String? photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
    if (photoUrl == null || photoUrl.isEmpty) {
      return Icon(
        Icons.person_outline,
        size: 18,
        color: isActive ? dellalioGoldSoft : panelSlate,
      );
    }
    return CircleAvatar(
      radius: 10,
      backgroundColor: inkSurfaceHover,
      backgroundImage: NetworkImage(photoUrl),
    );
  }
}

class _NavEntry {
  final IconData icon;
  final String label;
  final int index;
  const _NavEntry(this.icon, this.label, this.index);
}

class DashboardContent extends StatefulWidget {
  final Function(int) onNavigate;
  const DashboardContent({super.key, required this.onNavigate});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: inkPageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PAINEL GERAL",
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2,
                              color: panelSlateDim,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Bem-vindo, $displayNome",
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontWeight: FontWeight.w500,
                              fontSize: 27,
                              color: dellalioTitle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm:ss').format(_now),
                      style: TextStyle(
                        fontSize: 12,
                        color: panelSlateDim,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 14),
                    _UpdateButton(onPressed: () => _checkForUpdates(context)),
                  ],
                );
              },
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
            const SizedBox(height: 26),
            _buildKPISection(),
            const SizedBox(height: 22),
            _buildProximosCompromissosDestaque(user?.uid),
            _TimelinePanel(
              title: "PRIORIDADES DO DIA",
              child: _buildPriorityProjectsList(),
            ),
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
        final totalClientes = clientSnapshot.hasData
            ? clientSnapshot.data!.docs.length
            : 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('stock').snapshots(),
          builder: (context, stockSnapshot) {
            int estoqueCritico = 0;
            if (stockSnapshot.hasData) {
              for (var doc in stockSnapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                int q = data['quantity'] ?? 0;
                int m = data['minQuantity'] ?? 0;
                if (q <= (m + 10)) estoqueCritico++;
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reminders')
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

                    int chatsPendentes = 0;
                    if (chatSnapshot.hasData) {
                      for (var chatDoc in chatSnapshot.data!.docs) {
                        final data = chatDoc.data() as Map<String, dynamic>;
                        final unread = data['unreadCount'] as int?;
                        if (unread != null && unread > 0) chatsPendentes++;
                      }
                    }

                    return Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        _KpiCard(
                          label: "Clientes ativos",
                          value: totalClientes,
                          accentColor: dellalioGold,
                          sparkPoints: const [
                            0.2,
                            0.35,
                            0.25,
                            0.55,
                            0.5,
                            0.8,
                            0.95,
                          ],
                          delayIndex: 0,
                          onTap: () => widget.onNavigate(3),
                        ),
                        _KpiCard(
                          label: "Estoque crítico",
                          value: estoqueCritico,
                          accentColor: panelRust,
                          dotColor: panelRust,
                          sparkPoints: const [
                            0.75,
                            0.65,
                            0.7,
                            0.5,
                            0.55,
                            0.3,
                            0.15,
                          ],
                          delayIndex: 1,
                          onTap: () => widget.onNavigate(1),
                        ),
                        _KpiCard(
                          label: "Lembretes",
                          value: totalLembretes,
                          accentColor: navyAccent,
                          dotColor: navyAccent,
                          sparkPoints: const [
                            0.5,
                            0.5,
                            0.5,
                            0.5,
                            0.5,
                            0.5,
                            0.5,
                          ],
                          delayIndex: 2,
                          onTap: () => widget.onNavigate(2),
                        ),
                        _KpiCard(
                          label: "Mensagens",
                          value: totalChats,
                          accentColor: panelSage,
                          dotColor: panelSage,
                          badgeCount: chatsPendentes,
                          sparkPoints: const [
                            0.5,
                            0.5,
                            0.5,
                            0.5,
                            0.5,
                            0.5,
                            0.5,
                          ],
                          delayIndex: 3,
                          onTap: () => widget.onNavigate(5),
                        ),
                      ],
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

  Future<void> _checkForUpdates(BuildContext context) async {
    try {
      await autoUpdater.checkForUpdates();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verificando atualizações...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao verificar atualizações: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProximosCompromissosDestaque(String? userId) {
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('agenda')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 1)),
            ),
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final proximos = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final date = (data['date'] as Timestamp).toDate();
          return date.isAfter(now.subtract(const Duration(hours: 1)));
        }).toList();

        if (proximos.isEmpty) return const SizedBox.shrink();

        proximos.sort((a, b) {
          final da = (a.data() as Map<String, dynamic>)['date'] as Timestamp;
          final db = (b.data() as Map<String, dynamic>)['date'] as Timestamp;
          return da.toDate().compareTo(db.toDate());
        });

        final exibidos = proximos.take(5).toList();

        return _TimelinePanel(
          title: "PRÓXIMOS COMPROMISSOS",
          trailing: TextButton(
            onPressed: () => widget.onNavigate(7),
            style: TextButton.styleFrom(foregroundColor: dellalioGold),
            child: const Text("Ver agenda", style: TextStyle(fontSize: 12)),
          ),
          child: Column(
            children: exibidos.asMap().entries.map((entry) {
              final i = entry.key;
              final doc = entry.value;
              final data = doc.data() as Map<String, dynamic>;
              final date = (data['date'] as Timestamp).toDate();
              final text = data['text'] ?? '';
              final time = data['time'] ?? '';
              final int importancia = data['importancia'] ?? 0;
              final String userName = (data['userName'] ?? '?')
                  .toString()
                  .toUpperCase();

              final Color impColor = importancia >= 3
                  ? panelRust
                  : importancia >= 2
                  ? dellalioGold
                  : navyAccent;

              final String dataFormatada = DateFormat('dd/MM').format(date);
              final String horaStr = time.isNotEmpty ? ' às $time' : '';

              return _TimelineRow(
                markerColor: impColor,
                title: text.isNotEmpty ? text : 'Sem título',
                subtitle:
                    "${userName.isNotEmpty ? '$userName • ' : ''}$dataFormatada$horaStr",
                delayIndex: i,
                onTap: () => widget.onNavigate(7),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pedido':
        return statusPedido;
      case 'conferencia':
        return statusConferencia;
      case 'producao':
        return statusProducao;
      case 'montagem':
        return statusMontagem;
      case 'entrega':
        return statusEntrega;
      case 'finalizado':
        return statusFinalizado;
      default:
        return panelSlate;
    }
  }

  Widget _buildPriorityProjectsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clients').snapshots(),
      builder: (context, clientSnapshot) {
        if (!clientSnapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: dellalioGold),
            ),
          );
        }

        final clientDocs = clientSnapshot.data!.docs;
        final List<Stream<List<Map<String, dynamic>>>> projectStreams =
            clientDocs.map((clientDoc) {
              return clientDoc.reference
                  .collection('projects')
                  .where('status', isNotEqualTo: 'finalizado')
                  .snapshots()
                  .map(
                    (snap) => snap.docs.map((doc) {
                      final data = doc.data();
                      data['clientName'] =
                          (clientDoc.data() as Map<String, dynamic>)['name']
                              ?.toString()
                              .toUpperCase() ??
                          'CLIENTE';
                      return data;
                    }).toList(),
                  );
            }).toList();

        return StreamBuilder<List<List<Map<String, dynamic>>>>(
          stream: Rx.combineLatestList(projectStreams),
          builder: (context, projectSnapshot) {
            if (!projectSnapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(color: dellalioGold),
                ),
              );
            }

            final allProjects = projectSnapshot.data!.expand((i) => i).toList();
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
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  "Nenhuma prioridade pendente.",
                  style: TextStyle(color: panelSlate),
                ),
              );
            }

            return Column(
              children: limitedProjects.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final date = (data['deliveryDate'] as Timestamp).toDate();
                final String dataFormatada =
                    "${date.day}/${date.month}/${date.year}";
                final String rawStatus = (data['status'] ?? '').toString();
                final String status = rawStatus.isEmpty
                    ? 'N/A'
                    : rawStatus.toUpperCase();
                final Color statusColor = _statusColor(rawStatus);

                return _TimelineRow(
                  markerColor: statusColor,
                  title: (data['clientName'] ?? 'CLIENTE').toString(),
                  subtitle:
                      "${data['projectName']?.toString().toUpperCase() ?? 'PROJETO SEM NOME'} • Entrega $dataFormatada",
                  delayIndex: index,
                  trailing: _StatusPill(label: status, color: statusColor),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

/// Botão circular de "buscar atualizações", com leve giro no hover.
class _UpdateButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _UpdateButton({required this.onPressed});

  @override
  State<_UpdateButton> createState() => _UpdateButtonState();
}

class _UpdateButtonState extends State<_UpdateButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _hover ? dellalioGold : hairline,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 220),
            turns: _hover ? 0.06 : 0,
            child: Icon(
              Icons.refresh,
              size: 16,
              color: _hover ? dellalioGoldSoft : panelSlate,
            ),
          ),
        ),
      ),
    );
  }
}

/// Painel com título estilo "eyebrow" + conteúdo, entrando com fade/rise.
class _TimelinePanel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _TimelinePanel({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 1.6,
                  color: panelSlateDim,
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0),
    );
  }
}

/// Linha da lista de prioridades/compromissos, no estilo "linha do tempo".
class _TimelineRow extends StatefulWidget {
  final Color markerColor;
  final String title;
  final String subtitle;
  final int delayIndex;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _TimelineRow({
    required this.markerColor,
    required this.title,
    required this.subtitle,
    required this.delayIndex,
    this.trailing,
    this.onTap,
  });

  @override
  State<_TimelineRow> createState() => _TimelineRowState();
}

class _TimelineRowState extends State<_TimelineRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 18),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -18,
                top: 0,
                bottom: 0,
                child: Container(width: 1, color: hairlineNavy),
              ),
              Positioned(
                left: -21,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.markerColor,
                      border: Border.all(color: inkPageBg, width: 3),
                    ),
                  ),
                ),
              ),
              MouseRegion(
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _hover ? inkSurfaceHover : inkSurface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: _hover ? hairlineNavy : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: panelIvory,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: panelSlate,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.trailing != null) widget.trailing!,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
        .animate(delay: (70 * widget.delayIndex).ms)
        .fadeIn(duration: 380.ms)
        .slideX(begin: -0.03, end: 0, curve: Curves.easeOut);
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, this.color = dellalioGold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, letterSpacing: 0.6, color: color),
      ),
    );
  }
}

/// Card de KPI — alto e estreito, régua superior colorida, número que sobe
/// contando e uma mini sparkline decorativa, todos animados na entrada.
class _KpiCard extends StatefulWidget {
  final String label;
  final int value;
  final Color accentColor;
  final Color? dotColor;
  final int? badgeCount;
  final List<double> sparkPoints;
  final int delayIndex;
  final VoidCallback onTap;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.sparkPoints,
    required this.delayIndex,
    required this.onTap,
    this.dotColor,
    this.badgeCount,
  });

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final delay = (90 * widget.delayIndex).ms;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child:
            AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  transform: Matrix4.translationValues(0, _hover ? -5 : 0, 0),
                  width: 172,
                  height: 248,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _hover ? inkSurfaceHover : inkSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: hairline),
                  ),
                  child: Column(
                    children: [
                      Container(height: 2, color: widget.accentColor),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (widget.dotColor != null) ...[
                                        _PulsingDot(color: widget.dotColor!),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: Text(
                                          widget.label.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            letterSpacing: 1.3,
                                            color: panelSlate,
                                          ),
                                        ),
                                      ),
                                      if ((widget.badgeCount ?? 0) > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: panelRust,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '${widget.badgeCount}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 9),
                                  _GrowingRule(delay: delay + 200.ms),
                                ],
                              ),
                              _CountUpNumber(
                                target: widget.value,
                                color: panelIvory,
                                delay: delay + 400.ms,
                              ),
                              SizedBox(
                                height: 26,
                                child: _Sparkline(
                                  points: widget.sparkPoints,
                                  color: widget.accentColor,
                                  delay: delay + 450.ms,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .animate(delay: delay)
                .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                .slideY(begin: 0.09, end: 0, curve: Curves.easeOut),
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeOut(duration: 900.ms, curve: Curves.easeInOut)
        .then()
        .fadeIn(duration: 900.ms);
  }
}

class _GrowingRule extends StatelessWidget {
  final Duration delay;
  const _GrowingRule({required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: Container(height: 1, color: hairline),
      builder: (context, value, child) {
        return FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: child,
        );
      },
    ).animate(delay: delay).fadeIn(duration: 1.ms);
  }
}

/// Número que sobe contando de 0 até [target], iniciando após [delay].
class _CountUpNumber extends StatefulWidget {
  final int target;
  final Color color;
  final Duration delay;
  const _CountUpNumber({
    required this.target,
    required this.color,
    required this.delay,
  });

  @override
  State<_CountUpNumber> createState() => _CountUpNumberState();
}

class _CountUpNumberState extends State<_CountUpNumber> {
  bool _start = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _start = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: _start ? widget.target : 0),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOut,
      builder: (context, value, child) => Text(
        '$value',
        style: TextStyle(
          fontFamily: 'Fraunces',
          fontWeight: FontWeight.w500,
          fontSize: 44,
          height: 1,
          color: widget.color,
        ),
      ),
    );
  }
}

/// Mini gráfico de linha decorativo desenhado com CustomPainter — sem
/// dependências externas.
class _Sparkline extends StatelessWidget {
  final List<double> points;
  final Color color;
  final Duration delay;
  const _Sparkline({
    required this.points,
    required this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, value, child) => CustomPaint(
        size: const Size(double.infinity, 26),
        painter: _SparklinePainter(
          points: points,
          color: color,
          progress: value,
        ),
      ),
    ).animate(delay: delay).fadeIn(duration: 1.ms);
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final double progress;
  _SparklinePainter({
    required this.points,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final metrics = path.computeMetrics().first;
    final extractPath = metrics.extractPath(0, metrics.length * progress);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
