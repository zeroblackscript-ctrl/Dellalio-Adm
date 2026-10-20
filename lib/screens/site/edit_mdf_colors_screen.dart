import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';

/// Snapshot do que hoje está fixo em `mdf_colors_data.dart` no app cliente
/// — usado só pelo botão "Carregar dados atuais do app".
const List<Map<String, dynamic>> _currentAppDefaults = [
  {'name': 'Branco Polar', 'finish': 'Fosco', 'colorHex': 'F4F4F0'},
  {'name': 'Cinza Cristal', 'finish': 'Fosco', 'colorHex': '9E9E9E'},
  {'name': 'Carvalho', 'finish': 'Natural', 'colorHex': 'C39A6B'},
  {'name': 'Nogueira', 'finish': 'Natural', 'colorHex': '6B4A2F'},
  {'name': 'Preto Fosco', 'finish': 'Fosco', 'colorHex': '2B2B2B'},
  {'name': 'Freijó', 'finish': 'Natural', 'colorHex': 'D9B98C'},
];

Color _colorFromHex(String hex) {
  final clean = hex.replaceAll('#', '');
  final value = int.tryParse(clean, radix: 16) ?? 0xFFFFFF;
  return Color(0xFF000000 | value);
}

/// Editor da vitrine "Cores de MDF" — grava em `site_content/mdf_colors`
/// no formato `{ items: [{name, finish, colorHex}] }`.
///
/// Conteúdo embutível (sem Scaffold/navegação própria): [onBack] mostra a
/// seta de voltar quando embutido num shell que troca de conteúdo in-place;
/// [onDraftChanged] é chamado a cada mudança local, pra quem estiver
/// hospedando esta tela conseguir espelhar num preview ao vivo.
class EditMdfColorsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final ValueChanged<dynamic>? onDraftChanged;

  const EditMdfColorsScreen({super.key, this.onBack, this.onDraftChanged});

  @override
  State<EditMdfColorsScreen> createState() => _EditMdfColorsScreenState();
}

class _EditMdfColorsScreenState extends State<EditMdfColorsScreen> {
  final _doc = FirebaseFirestore.instance
      .collection('site_content')
      .doc('mdf_colors');

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cores salvas.')));
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
      builder: (_) => _ColorFormDialog(item: item),
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
          title: "Cores de MDF",
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
                          icon: Icons.palette_outlined,
                          title: "Nenhuma cor cadastrada",
                          subtitle:
                              "Carregue os dados atuais ou adicione uma nova",
                        ),
                      for (var i = 0; i < _items.length; i++)
                        _ColorTile(
                          data: _items[i],
                          onEdit: () => _openForm(item: _items[i], index: i),
                          onDelete: () => _remove(i),
                        ),
                      const SizedBox(height: 12),
                      DellalioGoldButton(
                        label: "Nova cor",
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

class _ColorTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ColorTile({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hex = (data['colorHex'] ?? 'FFFFFF').toString();
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
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _colorFromHex(hex),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
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
                  "${data['finish'] ?? ''} · #$hex",
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

class _ColorFormDialog extends StatefulWidget {
  final Map<String, dynamic>? item;
  const _ColorFormDialog({this.item});

  @override
  State<_ColorFormDialog> createState() => _ColorFormDialogState();
}

class _ColorFormDialogState extends State<_ColorFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _finishCtrl;
  late final TextEditingController _hexCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?['name'] ?? '');
    _finishCtrl = TextEditingController(text: widget.item?['finish'] ?? '');
    _hexCtrl = TextEditingController(
      text: (widget.item?['colorHex'] ?? 'FFFFFF').toString(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _finishCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return AlertDialog(
          backgroundColor: inkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            widget.item == null ? "Nova cor" : "Editar cor",
            style: TextStyle(color: panelIvory),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: _colorFromHex(_hexCtrl.text),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.15),
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
                  controller: _finishCtrl,
                  label: "Acabamento (ex: Fosco, Natural)",
                  icon: Icons.texture_outlined,
                ),
                const SizedBox(height: 12),
                DellalioFormField(
                  controller: _hexCtrl,
                  label: "Cor hexadecimal (sem #)",
                  icon: Icons.tag,
                  onChanged: (_) => setLocalState(() {}),
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
                'finish': _finishCtrl.text.trim(),
                'colorHex': _hexCtrl.text.trim().replaceAll('#', ''),
              }),
              child: const Text(
                "Salvar",
                style: TextStyle(color: dellalioGold),
              ),
            ),
          ],
        );
      },
    );
  }
}
