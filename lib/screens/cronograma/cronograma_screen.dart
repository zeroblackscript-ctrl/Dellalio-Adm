import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme.dart';

class CronogramaScreen extends StatefulWidget {
  const CronogramaScreen({super.key});

  @override
  State<CronogramaScreen> createState() => _CronogramaScreenState();
}

class _CronogramaScreenState extends State<CronogramaScreen> {
  static const List<String> statusSteps = [
    'CONFERÊNCIA',
    'PEDIDO',
    'PRODUÇÃO',
    'ENTREGA',
    'MONTAGEM',
    'FINALIZADO',
  ];
  static const List<String> statusKeys = [
    'conferencia',
    'pedido',
    'producao',
    'entrega',
    'montagem',
    'finalizado',
  ];

  int _statusIndex(String status) {
    final idx = statusKeys.indexOf(status);
    return idx >= 0 ? idx : 2; // fallback 'producao'
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Cronograma de produção",
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w500,
                fontSize: 27,
                color: dellalioTitle,
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
            const SizedBox(height: 26),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clients')
                  .snapshots(),
              builder: (context, clientSnapshot) {
                if (!clientSnapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: dellalioGold),
                    ),
                  );
                }

                final clientDocs = clientSnapshot.data!.docs;

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchAllProjects(clientDocs),
                  builder: (context, projectSnapshot) {
                    if (!projectSnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: dellalioGold),
                        ),
                      );
                    }

                    final projetos = projectSnapshot.data!;
                    if (projetos.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          "Nenhum projeto pendente.",
                          style: TextStyle(color: panelSlate),
                        ),
                      );
                    }

                    return Column(
                      children: projetos.asMap().entries.map((entry) {
                        final index = entry.key;
                        final pData = entry.value;
                        final dataEntrega =
                            (pData['deliveryDate'] as Timestamp?)?.toDate();
                        final String statusAtual =
                            pData['status'] ?? 'producao';

                        final int diasRestantes = dataEntrega != null
                            ? dataEntrega.difference(DateTime.now()).inDays
                            : 0;
                        final bool atrasado = diasRestantes < 0;
                        final String textoDias = atrasado
                            ? "ATRASADO"
                            : "$diasRestantes dias para entrega";

                        return _CronogramaCard(
                          projectName:
                              pData['projectName']?.toString().toUpperCase() ??
                              'SEM NOME',
                          clientName: (pData['clientName'] ?? '').toString(),
                          dueLabel: textoDias,
                          late: atrasado,
                          currentIndex: _statusIndex(statusAtual),
                          delayIndex: index % 12,
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllProjects(
    List<QueryDocumentSnapshot> clientDocs,
  ) async {
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
    allProjects.sort(
      (a, b) => (a['deliveryDate'] as Timestamp? ?? Timestamp.now()).compareTo(
        b['deliveryDate'] as Timestamp? ?? Timestamp.now(),
      ),
    );

    return allProjects;
  }
}

class _CronogramaCard extends StatelessWidget {
  final String projectName;
  final String clientName;
  final String dueLabel;
  final bool late;
  final int currentIndex;
  final int delayIndex;

  const _CronogramaCard({
    required this.projectName,
    required this.clientName,
    required this.dueLabel,
    required this.late,
    required this.currentIndex,
    required this.delayIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child:
          Container(
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
                decoration: BoxDecoration(
                  color: inkSurface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            projectName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: panelIvory,
                            ),
                          ),
                        ),
                        Text(
                          dueLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: late
                                ? const Color(0xFFE39A85)
                                : const Color(0xFF96C1A0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Cliente: $clientName",
                      style: TextStyle(fontSize: 12, color: panelSlate),
                    ),
                    const SizedBox(height: 20),
                    Container(height: 1, color: hairline),
                    const SizedBox(height: 20),
                    _Stepper(currentIndex: currentIndex),
                  ],
                ),
              )
              .animate(delay: (60 * delayIndex).ms)
              .fadeIn(duration: 420.ms, curve: Curves.easeOut)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int currentIndex;
  const _Stepper({required this.currentIndex});

  static const List<String> _labels = _CronogramaScreenState.statusSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_labels.length, (idx) {
        final bool isCurrent = idx == currentIndex;
        final bool isReached = idx <= currentIndex;
        final bool lineReached = idx < currentIndex;
        final bool isLast = idx == _labels.length - 1;

        return Expanded(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  if (!isLast)
                    Positioned(
                      left: 6,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: lineReached
                            ? dellalioGold.withValues(alpha: 0.35)
                            : hairline,
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _StepDot(isCurrent: isCurrent, isReached: isReached),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _labels[idx],
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 0.6,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    color: isCurrent
                        ? dellalioGoldSoft
                        : isReached
                        ? panelSlate
                        : panelSlateDim,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool isCurrent;
  final bool isReached;
  const _StepDot({required this.isCurrent, required this.isReached});

  @override
  Widget build(BuildContext context) {
    final double size = isCurrent ? 15 : 11;
    final Color fill = isCurrent
        ? dellalioGold
        : isReached
        ? dellalioGoldSoft
        : inkSurfaceHover;
    final Color border = isCurrent || isReached ? dellalioGold : panelSlateDim;

    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 1.4),
      ),
    );

    if (!isCurrent) return dot;

    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child:
              Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: dellalioGold),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .custom(
                    duration: 2000.ms,
                    builder: (context, value, child) => Opacity(
                      opacity: (1 - value) * 0.6,
                      child: Transform.scale(
                        scale: 1 + value * 0.9,
                        child: child,
                      ),
                    ),
                  ),
        ),
        dot,
      ],
    );
  }
}
