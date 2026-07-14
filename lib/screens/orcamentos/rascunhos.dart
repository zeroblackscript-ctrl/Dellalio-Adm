import 'package:DELLALIO/screens/orcamentos/imprimir_pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
      appBar: AppBar(title: const Text("Selecionar Projetos para PDF")),
      body: StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('orcamentos')
      .doc(widget.orcamentoId)
      .collection('projects')
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    
    // Converte os documentos em uma lista de mapas, incluindo o ID do documento
    final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
           itemBuilder: (ctx, i) {
  final doc = snapshot.data!.docs[i];
  final data = doc.data() as Map<String, dynamic>;
  final docId = doc.id; // O ID único do Firebase
              return CheckboxListTile(
                title: Text(data['nome'] ?? 'Projeto'),
                value: _selecionados[docId] ?? false, // Usa o ID aqui
                onChanged: (v) => setState(() => _selecionados[docId] = v!), // Salva o ID aqui
              );
            },
          );
        },
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
  label: const Text("Editar e Gerar PDF"),
  icon: const Icon(Icons.edit_note),
),
    );
  }
 }