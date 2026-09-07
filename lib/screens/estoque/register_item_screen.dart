import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';
import '../../models/item_model.dart';

class RegisterItemScreen extends StatefulWidget {
  const RegisterItemScreen({super.key});

  @override
  State<RegisterItemScreen> createState() => _RegisterItemScreenState();
}

class _RegisterItemScreenState extends State<RegisterItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _minQtyController = TextEditingController();

  Uint8List? _imageBytes;
  String _selectedCategory = 'Dobradiças';
  bool _isLoading = false;

  final List<String> _categories = [
    'Dobradiças',
    'Corrediças',
    'Perfis',
    'Puxadores',
    'Parafusos',
    'Acessórios / Outros',
  ];


  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) setState(() => _imageBytes = result.files.first.bytes);
  }

  void _saveItem() async {
    if (!_formKey.currentState!.validate() || _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos e selecione uma foto!'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref('stock_items/$fileName');
      await ref.putData(_imageBytes!);
      String imageUrl = await ref.getDownloadURL();

      final docRef = FirebaseFirestore.instance.collection('stock').doc();
      final newItem = ItemModel(
        id: docRef.id,
        name: _nameController.text.trim(),
        category: _selectedCategory,
        quantity: int.parse(_qtyController.text.trim()),
        minQuantity: int.parse(_minQtyController.text.trim()),
        imageUrl: imageUrl,
      );

      await docRef.set(newItem.toMap());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    return Scaffold(
      backgroundColor: inkPageBg,
      body: Column(
        children: [
          const DellalioSubHeader(title: "Novo insumo"),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: inkSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: hairline),
                      ),
                      child: _imageBytes == null
                          ? const Center(
                              child: Icon(
                                Icons.add_a_photo,
                                size: 50,
                                color: dellalioGold,
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  DellalioFormField(
                    controller: _nameController,
                    label: "Nome do componente",
                    icon: Icons.widgets_outlined,
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    dropdownColor: inkSurface,
                    style: TextStyle(color: panelIvory, fontSize: 13.5),
                    decoration: InputDecoration(
                      labelText: "Categoria",
                      labelStyle: TextStyle(color: panelSlate, fontSize: 13),
                      filled: true,
                      fillColor: inkSurface,
                      prefixIcon: Icon(Icons.category_outlined,
                          size: 18, color: panelSlate),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: hairlineNavy, width: 1.4),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: hairline),
                      ),
                    ),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: DellalioFormField(
                          controller: _qtyController,
                          label: "Qtd inicial",
                          icon: Icons.inventory_2_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: DellalioFormField(
                          controller: _minQtyController,
                          label: "Estoque mínimo",
                          icon: Icons.notification_important_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: dellalioGold),
                    )
                  else
                    DellalioGoldButton(
                      label: "Salvar no estoque",
                      icon: Icons.save_outlined,
                      fullWidth: true,
                      onPressed: _saveItem,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    ],
    ),
    );
  }
}
