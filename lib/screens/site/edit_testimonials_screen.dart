import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/dellalio_kit.dart';
import '../../core/media_upload.dart';
import '../../core/theme.dart';

/// Snapshot do que hoje está fixo em `testimonials_data.dart` no app cliente
/// — usado só pelo botão "Carregar dados atuais do app".
const List<Map<String, dynamic>> _currentAppDefaults = [
  {
    'clientName': 'Mariana Lopes',
    'city': 'São Paulo',
    'rating': 5,
    'quote':
        'Do projeto ao acabamento, tudo foi impecável. A cozinha ficou '
        'exatamente como sonhei — cada milímetro aproveitado.',
    'photoUrl': null,
  },
  {
    'clientName': 'Rafael Moura',
    'city': 'Campinas',
    'rating': 5,
    'quote':
        'Acompanhei cada etapa pelo app. Quando chegaram pra montar, '
        'foi rápido, limpo e sem nenhuma surpresa.',
    'photoUrl': null,
  },
  {
    'clientName': 'Camila e Bruno',
    'city': 'Jundiaí',
    'rating': 4,
    'quote':
        'O closet ficou perfeito. O único adiamento foi por causa da '
        'nossa obra, e mesmo assim entregaram no remanejado.',
    'photoUrl': null,
  },
  {
    'clientName': 'Fernanda Reis',
    'city': 'Santos',
    'rating': 5,
    'quote':
        'Ferragem de verdade, acabamento impecável. Dá pra sentir a '
        'qualidade no toque. Recomendo de olhos fechados.',
    'photoUrl': null,
  },
];

/// Editor da vitrine "Depoimentos" — grava em `site_content/testimonials`
/// no formato `{ items: [{clientName, city, rating, quote, photoUrl}] }`.
///
/// Conteúdo embutível (sem Scaffold/navegação própria): [onBack] mostra a
/// seta de voltar quando embutido num shell que troca de conteúdo in-place;
/// [onDraftChanged] é chamado a cada mudança local, pra quem estiver
/// hospedando esta tela conseguir espelhar num preview ao vivo.
class EditTestimonialsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final ValueChanged<dynamic>? onDraftChanged;

  const EditTestimonialsScreen({
    super.key,
    this.onBack,
    this.onDraftChanged,
  });

  @override
  State<EditTestimonialsScreen> createState() =>
      _EditTestimonialsScreenState();
}

class _EditTestimonialsScreenState extends State<EditTestimonialsScreen> {
  final _doc = FirebaseFirestore.instance
      .collection('site_content')
      .doc('testimonials');

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
        ).showSnackBar(const SnackBar(content: Text('Depoimentos salvos.')));
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
      builder: (_) => _TestimonialFormDialog(item: item),
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
          title: "Depoimentos",
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
                          icon: Icons.format_quote_outlined,
                          title: "Nenhum depoimento cadastrado",
                          subtitle:
                              "Carregue os dados atuais ou adicione um novo",
                        ),
                      for (var i = 0; i < _items.length; i++)
                        _TestimonialTile(
                          data: _items[i],
                          onEdit: () => _openForm(item: _items[i], index: i),
                          onDelete: () => _remove(i),
                        ),
                      const SizedBox(height: 12),
                      DellalioGoldButton(
                        label: "Novo depoimento",
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

class _TestimonialTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TestimonialTile({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = data['photoUrl'] as String?;
    final rating = (data['rating'] as num?)?.toInt() ?? 5;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: inkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: SizedBox(
              width: 40,
              height: 40,
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(photoUrl, fit: BoxFit.cover)
                  : Container(
                      color: inkSurfaceHover,
                      child: Icon(
                        Icons.person_outline,
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
                Row(
                  children: [
                    Text(
                      "${data['clientName'] ?? ''} · ${data['city'] ?? ''}",
                      style: TextStyle(color: panelIvory, fontSize: 13.5),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating ? Icons.star : Icons.star_border,
                          size: 13,
                          color: dellalioGold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  (data['quote'] ?? '').toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: panelSlateDim, fontSize: 12),
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

class _TestimonialFormDialog extends StatefulWidget {
  final Map<String, dynamic>? item;
  const _TestimonialFormDialog({this.item});

  @override
  State<_TestimonialFormDialog> createState() =>
      _TestimonialFormDialogState();
}

class _TestimonialFormDialogState extends State<_TestimonialFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _quoteCtrl;
  int _rating = 5;
  String? _photoUrl;
  Uint8List? _newPhotoBytes;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?['clientName'] ?? '');
    _cityCtrl = TextEditingController(text: widget.item?['city'] ?? '');
    _quoteCtrl = TextEditingController(text: widget.item?['quote'] ?? '');
    _rating = (widget.item?['rating'] as num?)?.toInt() ?? 5;
    _photoUrl = widget.item?['photoUrl'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _quoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final bytes = await pickImageBytes();
    if (bytes == null) return;
    setState(() {
      _newPhotoBytes = bytes;
      _uploading = true;
    });
    try {
      final url = await uploadSiteContentMedia(bytes, 'testimonials');
      if (mounted) setState(() => _photoUrl = url);
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
        widget.item == null ? "Novo depoimento" : "Editar depoimento",
        style: TextStyle(color: panelIvory),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _uploading ? null : _pickPhoto,
                child: ClipOval(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: _uploading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: dellalioGold,
                            ),
                          )
                        : _newPhotoBytes != null
                        ? Image.memory(_newPhotoBytes!, fit: BoxFit.cover)
                        : (_photoUrl != null && _photoUrl!.isNotEmpty)
                        ? Image.network(_photoUrl!, fit: BoxFit.cover)
                        : Container(
                            color: inkSurfaceHover,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.add_a_photo_outlined,
                              color: panelSlateDim,
                              size: 18,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DellalioFormField(
                controller: _nameCtrl,
                label: "Nome do cliente",
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              DellalioFormField(
                controller: _cityCtrl,
                label: "Cidade",
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 12),
              DellalioFormField(
                controller: _quoteCtrl,
                label: "Depoimento",
                icon: Icons.format_quote_outlined,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setLocalState) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = i < _rating;
                    return IconButton(
                      icon: Icon(
                        filled ? Icons.star : Icons.star_border,
                        color: dellalioGold,
                      ),
                      onPressed: () =>
                          setLocalState(() => setState(() => _rating = i + 1)),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar", style: TextStyle(color: panelSlate)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'clientName': _nameCtrl.text.trim(),
            'city': _cityCtrl.text.trim(),
            'rating': _rating,
            'quote': _quoteCtrl.text.trim(),
            'photoUrl': _photoUrl,
          }),
          child: const Text("Salvar", style: TextStyle(color: dellalioGold)),
        ),
      ],
    );
  }
}
