import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';

/// Tela de Histórico de Retiradas do Estoque (somente Admin).
/// Lê os logs da subcoleção `logs` dentro de cada documento da coleção `stock`
/// usando uma Collection Group Query.
class StockHistoryScreen extends StatelessWidget {
  const StockHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: Column(
        children: [
          const DellalioSubHeader(title: "Histórico de estoque"),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Collection Group Query: busca TODOS os documentos da subcoleção
              // 'logs' em qualquer documento pai (stock/{itemId}/logs)
              stream: FirebaseFirestore.instance
                  .collectionGroup('logs')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return DellalioEmptyState(
                    icon: Icons.error_outline,
                    title: "Erro ao carregar histórico",
                    subtitle: "${snapshot.error}",
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: dellalioGold),
                  );
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const DellalioEmptyState(
                    icon: Icons.history,
                    title: "Nenhuma retirada registrada",
                    subtitle: "As saídas de estoque aparecerão aqui.",
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      itemCount: docs.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data =
                            docs[index].data() as Map<String, dynamic>;
                        final ts = data['timestamp'];
                        String dateStr = '--/--/---- --:--';
                        if (ts is Timestamp) {
                          dateStr = DateFormat('dd/MM/yyyy  HH:mm')
                              .format(ts.toDate());
                        }

                        final int previousQty = data['previousQty'] ?? 0;
                        final int amountWithdrawn = data['amountWithdrawn'] ?? 0;
                        final int newQty = data['newQty'] ?? 0;
                        final String itemName =
                            (data['itemName'] ?? 'Item desconhecido').toString();
                        final String userName =
                            (data['userName'] ?? 'Desconhecido').toString();

                        return DellalioCard(
                          delayIndex: index % 12,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: panelRust.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(Icons.remove_circle_outline,
                                    size: 18, color: panelRust),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            itemName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: panelIvory,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        DellalioBadge(
                                          label: "-$amountWithdrawn un",
                                          color: panelRust,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Estoque: $previousQty  →  $newQty",
                                      style: TextStyle(
                                          color: panelSlate, fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Por: $userName   •   $dateStr",
                                      style: TextStyle(
                                          color: panelSlateDim, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
