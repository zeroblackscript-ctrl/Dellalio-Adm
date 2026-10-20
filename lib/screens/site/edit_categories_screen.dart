import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/dellalio_kit.dart';
import '../../core/media_upload.dart';
import '../../core/theme.dart';

/// Snapshot do que hoje está fixo em `categories_data.dart` no app cliente
/// — usado só pelo botão "Carregar dados atuais do app".
const List<Map<String, dynamic>> _currentAppDefaults = [
  {'name': 'Cozinha', 'imageUrl': null, 'filterTag': 'cozinha'},
  {'name': 'Quarto', 'imageUrl': null, 'filterTag': 'quarto'},
  {'name': 'Closet', 'imageUrl': null, 'filterTag': 'closet'},
  {'name': 'Sala', 'imageUrl': null, 'filterTag': 'sala'},
  {'name': 'Home Office', 'imageUrl': null, 'filterTag': 'home-office'},
  {'name': 'Banheiro', 'imageUrl': null, 'filterTag': 'banheiro'},
];

/// Editor da vitrine "Categorias de ambientes" — grava em
/// `site_content/categories` no formato `{ items: [{name, imageUrl, filterTag}] }`.
///
/// Conteúdo embutível (sem Scaffold/navegação própria): [onBack] mostra a
/// seta de voltar quando embutido num shell que troca de conteúdo in-place;
/// [onDraftChanged] é chamado a cada mudança local, pra quem estiver
/// hospedando esta tela conseguir espelhar num preview ao vivo.
class EditCategoriesScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final ValueChanged<dynamic>? onDraftChanged;

  const EditCategoriesScreen({super.key, this.onBack, this.onDraftChanged});

  @override
  State<EditCategoriesScreen> createState() => _EditCategoriesScreenState();
}

class _EditCategoriesScreenState extends State<EditCategoriesScreen> {
  final _doc = FirebaseFirestore.instance
      .collection('site_content')
      .doc('categories');

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _docExists = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _notify() => widget.onDraftChanged?.call(_items);

  Future<void> _load() async {
    final snap = await _doc.get();
    setState(() {
      _docExists = snap.exists;
      final items = snap.data()?['items'] as List?;
      _items = items?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      _loading = false;
    });
    _notify();
  }

  void _seedFromApp() {
    setState(() {
      _items = _currentAppDefaults
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
    _notify();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _doc.set({'items': _items});
      if (mounted) {
        setState(() => _docExists = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Categorias salvas.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? item, int? index}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CategoryFormDialog(item: item),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _items[index] = result;
      } else {
        _items.add(result);
      }
    });
    _notify();
  }

  void _remove(int index) {
    setState(() => _items.removeAt(index));
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorInlineHeader(
          title: "Categorias de ambientes",
          onBack: widget.onBack,
          saving: _saving,
          onSave: _save,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: dellalioGold),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_docExists)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DellalioGhostButton(
                            label: "Carregar dados atuais do app",
                            icon: Icons.cloud_download_outlined,
                            onPressed: _seedFromApp,
                          ),
                        ),
                      if (_items.isEmpty)
                        const DellalioEmptyState(
                          icon: Icons.grid_view_outlined,
                          title: "Nenhuma categoria cadastrada",
                          subtitle:
                              "Carregue os dados atuais ou adicione uma nova",
                        ),
                      for (var i = 0; i < _items.length; i++)
                        _CategoryTile(
                          data: _items[i],
                          onEdit: () => _openForm(item: _items[i], index: i),
                          onDelete: () => _remove(i),
                        ),
                      const SizedBox(height: 12),
                      DellalioGoldButton(
                        label: "Nova categoria",
                        fullWidth: true,
                        onPressed: () => _openForm(),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['imageUrl'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: inkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hairline),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 44,
              height: 44,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Container(
                      color: inkSurfaceHover,
                      child: Icon(
                        Icons.image_outlined,
                        color: panelSlateDim,
                        size: 18,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['name'] ?? '').toString(),
                  style: TextStyle(color: panelIvory, fontSize: 14),
                ),
                Text(
                  "tag: ${data['filterTag'] ?? ''}",
                  style: TextStyle(color: panelSlateDim, fontSize: 11.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: panelSlate, size: 18),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: panelRust, size: 18),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _CategoryFormDialog extends StatefulWidget {
  final Map<String, dynamic>? item;
  const _CategoryFormDialog({this.item});

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tagCtrl;
  String? _imageUrl;
  Uint8List? _newImageBytes;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?['name'] ?? '');
    _tagCtrl = TextEditingController(text: widget.item?['filterTag'] ?? '');
    _imageUrl = widget.item?['imageUrl'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final bytes = await pickImageBytes();
    if (bytes == null) return;
    setState(() {
      _newImageBytes = bytes;
      _uploading = true;
    });
    try {
      final url = await uploadSiteContentMedia(bytes, 'categories');
      if (mounted) setState(() => _imageUrl = url);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: inkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Text(
        widget.item == null ? "Nova categoria" : "Editar categoria",
        style: TextStyle(color: panelIvory),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _uploading ? null : _pickImage,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: _uploading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: dellalioGold,
                          ),
                        )
                      : _newImageBytes != null
                      ? Image.memory(_newImageBytes!, fit: BoxFit.cover)
                      : (_imageUrl != null && _imageUrl!.isNotEmpty)
                      ? Image.network(_imageUrl!, fit: BoxFit.cover)
                      : Container(
                          color: inkSurfaceHover,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            color: panelSlateDim,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DellalioFormField(
              controller: _nameCtrl,
              label: "Nome",
              icon: Icons.label_outline,
            ),
            const SizedBox(height: 12),
            DellalioFormField(
              controller: _tagCtrl,
              label: "Tag de filtro (ex: cozinha)",
              icon: Icons.filter_alt_outlined,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar", style: TextStyle(color: panelSlate)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'name': _nameCtrl.text.trim(),
            'imageUrl': _imageUrl,
            'filterTag': _tagCtrl.text.trim(),
          }),
          child: const Text("Salvar", style: TextStyle(color: dellalioGold)),
        ),
      ],
    );
  }
}
