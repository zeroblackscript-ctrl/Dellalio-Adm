import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Tela de Histórico de Retiradas do Estoque (somente Admin).
/// Lê os logs da subcoleção `logs` dentro de cada documento da coleção `stock`
/// usando uma Collection Group Query.
class StockHistoryScreen extends StatelessWidget {
  const StockHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text(
          "HISTÓRICO DE ESTOQUE",
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Collection Group Query: busca TODOS os documentos da subcoleção 'logs'
        // em qualquer documento pai (stock/{itemId}/logs)
        stream: FirebaseFirestore.instance
            .collectionGroup('logs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Erro: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            );
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "Nenhuma retirada registrada ainda.",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final ts = data['timestamp'];
              String dateStr = '--/--/---- --:--';
              if (ts is Timestamp) {
                dateStr = DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate());
              }

              final int previousQty = data['previousQty'] ?? 0;
              final int amountWithdrawn = data['amountWithdrawn'] ?? 0;
              final int newQty = data['newQty'] ?? 0;
              final String itemName = (data['itemName'] ?? 'Item desconhecido').toString();
              final String userName = (data['userName'] ?? 'Desconhecido').toString();

              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    itemName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    "Retirado: $amountWithdrawn un.  "
                    "(Estoque: $previousQty → $newQty)\n"
                    "Por: $userName",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}