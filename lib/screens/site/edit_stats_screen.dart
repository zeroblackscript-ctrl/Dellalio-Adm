import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';

/// Snapshot do que hoje está fixo em `home_showcase_screen.dart` (demoStats)
/// — usado só pelo botão "Carregar dados atuais do app".
const List<Map<String, dynamic>> _currentAppDefaults = [
  {'value': 180, 'suffix': '+', 'label': 'projetos entregues'},
  {'value': 2, 'suffix': '', 'label': 'anos de mercado'},
  {'value': 98, 'suffix': '%', 'label': 'clientes satisfeitos'},
];

/// Editor da vitrine "Números da empresa" — grava em `site_content/stats`
/// no formato `{ items: [{value, suffix, label}] }`.
///
/// Conteúdo embutível (sem Scaffold/navegação própria): [onBack] mostra a
/// seta de voltar quando embutido num shell que troca de conteúdo in-place;
/// [onDraftChanged] é chamado a cada mudança local, pra quem estiver
/// hospedando esta tela conseguir espelhar num preview ao vivo.
class EditStatsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final ValueChanged<dynamic>? onDraftChanged;

  const EditStatsScreen({super.key, this.onBack, this.onDraftChanged});

  @override
  State<EditStatsScreen> createState() => _EditStatsScreenState();
}

class _EditStatsScreenState extends State<EditStatsScreen> {
  final _doc = FirebaseFirestore.instance
      .collection('site_content')
      .doc('stats');

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
        ).showSnackBar(const SnackBar(content: Text('Números salvos.')));
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
      builder: (_) => _StatFormDialog(item: item),
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
          title: "Números da empresa",
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
                          icon: Icons.bar_chart_outlined,
                          title: "Nenhum número cadastrado",
                          subtitle:
                              "Carregue os dados atuais ou adicione um novo",
                        ),
                      for (var i = 0; i < _items.length; i++)
                        _StatTile(
                          data: _items[i],
                          onEdit: () => _openForm(item: _items[i], index: i),
                          onDelete: () => _remove(i),
                        ),
                      const SizedBox(height: 12),
                      DellalioGoldButton(
                        label: "Novo número",
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

class _StatTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StatTile({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(
            "${data['value'] ?? 0}${data['suffix'] ?? ''}",
            style: const TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 20,
              color: dellalioGold,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              (data['label'] ?? '').toString(),
              style: TextStyle(color: panelIvory, fontSize: 13.5),
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

class _StatFormDialog extends StatefulWidget {
  final Map<String, dynamic>? item;
  const _StatFormDialog({this.item});

  @override
  State<_StatFormDialog> createState() => _StatFormDialogState();
}

class _StatFormDialogState extends State<_StatFormDialog> {
  late final TextEditingController _valueCtrl;
  late final TextEditingController _suffixCtrl;
  late final TextEditingController _labelCtrl;

  @override
  void initState() {
    super.initState();
    _valueCtrl = TextEditingController(
      text: (widget.item?['value'] ?? 0).toString(),
    );
    _suffixCtrl = TextEditingController(text: widget.item?['suffix'] ?? '');
    _labelCtrl = TextEditingController(text: widget.item?['label'] ?? '');
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _suffixCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: inkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Text(
        widget.item == null ? "Novo número" : "Editar número",
        style: TextStyle(color: panelIvory),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: DellalioFormField(
                    controller: _valueCtrl,
                    label: "Valor",
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DellalioFormField(
                    controller: _suffixCtrl,
                    label: "Sufixo (ex: +, %)",
                    icon: Icons.add,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DellalioFormField(
              controller: _labelCtrl,
              label: "Legenda",
              icon: Icons.label_outline,
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
            'value': int.tryParse(_valueCtrl.text.trim()) ?? 0,
            'suffix': _suffixCtrl.text.trim(),
            'label': _labelCtrl.text.trim(),
          }),
          child: const Text("Salvar", style: TextStyle(color: dellalioGold)),
        ),
      ],
    );
  }
}
