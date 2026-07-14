import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/user_session.dart';

class EditItemScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditItemScreen({super.key, required this.docId, required this.data});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  Uint8List? _newImageBytes; // Armazena a nova foto, se o usuário escolher
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _qtyController;
  late TextEditingController _minQtyController;
  late String _selectedCategory;
  bool _isLoading = false;
  late int _previousQuantity;

  final List<String> _categories = [
    'Dobradiças',
    'Corrediças',
    'Perfis',
    'Puxadores',
    'Parafusos',
    'Acessórios / Outros',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data['name']);
    _previousQuantity = (widget.data['quantity'] ?? 0) as int;
    _qtyController = TextEditingController(
      text: widget.data['quantity'].toString(),
    );
    _minQtyController = TextEditingController(
      text: widget.data['minQuantity'].toString(),
    );
    _selectedCategory = widget.data['category'] ?? _categories.first;
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFD4AF37)),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
    ),
  );

  void _updateItem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String imageUrl = widget.data['imageUrl'];

      // Se uma nova imagem foi selecionada, faz o upload
      if (_newImageBytes != null) {
        String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref('stock_items/$fileName');
        await ref.putData(_newImageBytes!);
        imageUrl = await ref.getDownloadURL();
      }

      final int newQuantity = int.parse(_qtyController.text.trim());

      await FirebaseFirestore.instance
          .collection('stock')
          .doc(widget.docId)
          .update({
            'name': _nameController.text.trim(),
            'category': _selectedCategory,
            'quantity': newQuantity,
            'minQuantity': int.parse(_minQtyController.text.trim()),
            'imageUrl':
                imageUrl, // Salva a nova URL (ou a anterior, se não mudou)
          });

      // Se a quantidade diminuiu, registra automaticamente uma retirada
      // no histórico de estoque (stock_logs), visível apenas para Admin.
      if (newQuantity < _previousQuantity) {
        final user = FirebaseAuth.instance.currentUser;
        await FirebaseFirestore.instance.collection('stock_logs').add({
          'itemId': widget.docId,
          'itemName': _nameController.text.trim(),
          'previousQty': _previousQuantity,
          'newQty': newQuantity,
          'amountWithdrawn': _previousQuantity - newQuantity,
          'userName': user?.displayName ?? user?.email ?? 'Desconhecido',
          'userId': user?.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteItem() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          "Excluir Item",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Tem certeza que deseja remover este item do estoque?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Excluir", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('stock')
          .doc(widget.docId)
          .delete();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _minQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = UserSession.isAdmin();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: Text(
          isAdmin ? "EDITAR INSUMO" : "DETALHES DO INSUMO",
          style: const TextStyle(color: Color(0xFFD4AF37)),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteItem,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: AbsorbPointer(
                absorbing: !isAdmin,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Exibição da foto atual
                    GestureDetector(
                      onTap: () async {
                        FilePickerResult? result = await FilePicker.pickFiles(
                          type: FileType.image,
                          withData: true,
                        );
                        if (result != null) {
                          setState(
                            () => _newImageBytes = result.files.first.bytes,
                          );
                        }
                      },
                      child: _newImageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _newImageBytes!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                widget.data['imageUrl'],
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                    const SizedBox(height: 25),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('NOME DO COMPONENTE'),
                      validator: (v) =>
                          v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('CATEGORIA'),
                      items: _categories
                          .map(
                            (c) =>
                                DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('QTD ATUAL'),
                            validator: (v) =>
                                v!.isEmpty ? 'Obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: TextFormField(
                            controller: _minQtyController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('ESTOQUE MÍNIMO'),
                            validator: (v) =>
                                v!.isEmpty ? 'Obrigatório' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    if (isAdmin)
                      ElevatedButton(
                        onPressed: _isLoading ? null : _updateItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.black,
                              )
                            : const Text(
                                "SALVAR ALTERAÇÕES",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    if (!isAdmin)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          "Apenas o administrador pode editar itens do estoque.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
