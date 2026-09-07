import 'package:DELLALIO/screens/orcamentos/imprimir_pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';

class ListarRascunhosScreen extends StatefulWidget {
  final String orcamentoId;
  const ListarRascunhosScreen({super.key, required this.orcamentoId});

  @override
  State<ListarRascunhosScreen> createState() => _ListarRascunhosScreenState();
}

class _ListarRascunhosScreenState extends State<ListarRascunhosScreen> {
final Map<String, bool> _selecionados = {};
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: Column(
        children: [
          const DellalioSubHeader(title: "Selecionar projetos para PDF"),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('orcamentos')
      .doc(widget.orcamentoId)
      .collection('projects')
      .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: dellalioGold),
                );
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const DellalioEmptyState(
                  icon: Icons.checklist,
                  title: "Nenhum projeto para selecionar",
                  subtitle: "Cadastre um projeto antes de gerar o PDF.",
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final docId = doc.id;
                  final bool selected = _selecionados[docId] ?? false;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? dellalioGold.withValues(alpha: 0.08)
                          : inkSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? dellalioGold : hairline,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: selected,
                      activeColor: dellalioGold,
                      checkColor: inkPageBg,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      title: Text(
                        data['nome'] ?? 'Projeto',
                        style: TextStyle(
                          color: selected ? dellalioGoldSoft : panelIvory,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onChanged: (v) =>
                          setState(() => _selecionados[docId] = v!),
                    ),
                  ).animate(delay: (50 * (i % 12)).ms)
                      .fadeIn(duration: 380.ms)
                      .slideY(begin: 0.08, end: 0);
                },
              );
            },
          ),
        ),
      ],
    ),
      floatingActionButton: FloatingActionButton.extended(
  onPressed: () async {
    // 1. Busca os documentos atuais diretamente da coleção
    final querySnapshot = await FirebaseFirestore.instance
        .collection('orcamentos')
        .doc(widget.orcamentoId)
        .collection('projects')
        .get();
        
    final todosDocs = querySnapshot.docs;
    
    // 2. Filtra os selecionados comparando o ID do documento
    // Usamos o .where() para pegar apenas os documentos cujo ID está marcado como 'true' no mapa
    final selecionados = todosDocs
        .where((doc) => _selecionados[doc.id] == true) 
        .map((doc) => {
          'id': doc.id, 
          ...doc.data() as Map<String, dynamic>
        })
        .toList();

    if (selecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione ao menos um projeto!"))
      );
      return;
    }

    // 3. Navega passando a lista de mapas (objetos)
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => VisualizarPdfScreen(
        ambientesSelecionados: selecionados,
        dadosCliente: {}, orcamentoId: widget.orcamentoId, // Preencha com os dados do cliente conforme sua estrutura
      )
    ));
  },
  backgroundColor: dellalioGold,
  foregroundColor: inkPageBg,
  label: const Text("Gerar PDF", style: TextStyle(fontWeight: FontWeight.w600)),
  icon: const Icon(Icons.edit_note),
),
    );
  }
 }