import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/dellalio_kit.dart';
import '../../core/media_upload.dart';
import '../../core/theme.dart';

const List<String> _positions = [
  'topLeft',
  'topRight',
  'center',
  'bottomLeft',
  'bottomRight',
];

const Map<String, String> _positionLabels = {
  'topLeft': 'Superior esquerda',
  'topRight': 'Superior direita',
  'center': 'Centro',
  'bottomLeft': 'Inferior esquerda',
  'bottomRight': 'Inferior direita',
};

/// Editor da vitrine "Projeto em destaque" — grava em
/// `site_content/spotlight_project` no formato
/// `{ title, tagline, photos: [...], highlights: [{label, description, photoIndex, position}] }`.
/// Conteúdo embutível (sem Scaffold/navegação própria): [onBack] mostra a
/// seta de voltar quando embutido num shell que troca de conteúdo in-place;
/// [onDraftChanged] é chamado a cada mudança local, pra quem estiver
/// hospedando esta tela conseguir espelhar num preview ao vivo.
class EditSpotlightProjectScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final ValueChanged<dynamic>? onDraftChanged;

  const EditSpotlightProjectScreen({
    super.key,
    this.onBack,
    this.onDraftChanged,
  });

  @override
  State<EditSpotlightProjectScreen> createState() =>
      _EditSpotlightProjectScreenState();
}

class _EditSpotlightProjectScreenState
    extends State<EditSpotlightProjectScreen> {
  final _doc = FirebaseFirestore.instance
      .collection('site_content')
      .doc('spotlight_project');

  late final TextEditingController _titleCtrl;
  late final TextEditingController _taglineCtrl;
  List<String> _photos = [];
  List<Map<String, dynamic>> _highlights = [];

  bool _loading = true;
  bool _docExists = false;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _taglineCtrl = TextEditingController();
    for (final c in [_titleCtrl, _taglineCtrl]) {
      c.addListener(() {
        setState(() {});
        _notify();
      });
    }
    _load();
  }

  void _notify() => widget.onDraftChanged?.call({
    'title': _titleCtrl.text,
    'tagline': _taglineCtrl.text,
    'photos': _photos,
    'highlights': _highlights,
  });

  @override
  void dispose() {
    _titleCtrl.dispose();
    _taglineCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final snap = await _doc.get();
    final data = snap.data();
    setState(() {
      _docExists = snap.exists;
      _titleCtrl.text = data?['title'] as String? ?? '';
      _taglineCtrl.text = data?['tagline'] as String? ?? '';
      _photos = (data?['photos'] as List?)?.map((e) => e.toString()).toList() ?? [];
      _highlights = (data?['highlights'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      _loading = false;
    });
    _notify();
  }

  void _seedFromApp() {
    setState(() {
      _titleCtrl.text = 'Lavanderia Colonial';
      _taglineCtrl.text = 'Moldura clássica · ferragens douradas';
      _photos = [
        'assets/imagens/ambientes/lavanderia 1 poli.jpeg',
        'assets/imagens/ambientes/lavanderia 2 poli.jpeg',
        'assets/imagens/ambientes/lavanderia 3 poli.jpeg',
      ];
      _highlights = [
        {
          'label': 'Ferragens douradas',
          'description': 'Puxadores sob medida',
          'photoIndex': 0,
          'position': 'topLeft',
        },
        {
          'label': 'Vidro canelado',
          'description': 'Portas em arco no nicho',
          'photoIndex': 0,
          'position': 'center',
        },
      ];
    });
    _notify();
  }

  Future<void> _addPhoto() async {
    final bytes = await pickImageBytes();
    if (bytes == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await uploadSiteContentMedia(bytes, 'spotlight_project');
      if (mounted) setState(() => _photos.add(url));
      _notify();
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      // Mantém os highlights consistentes: quem apontava pra essa foto
      // passa a apontar pra primeira.
      for (final h in _highlights) {
        if ((h['photoIndex'] as num?)?.toInt() == index) h['photoIndex'] = 0;
      }
    });
    _notify();
  }

  Future<void> _openHighlightForm({
    Map<String, dynamic>? highlight,
    int? index,
  }) async {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione uma foto antes.')),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _HighlightFormDialog(
        highlight: highlight,
        photoCount: _photos.length,
      ),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _highlights[index] = result;
      } else {
        _highlights.add(result);
      }
    });
    _notify();
  }

  void _removeHighlight(int index) {
    setState(() => _highlights.removeAt(index));
    _notify();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _doc.set({
        'title': _titleCtrl.text.trim(),
        'tagline': _taglineCtrl.text.trim(),
        'photos': _photos,
        'highlights': _highlights,
      });
      if (mounted) {
        setState(() => _docExists = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projeto em destaque salvo.')),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorInlineHeader(
          title: "Projeto em destaque",
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
                            DellalioFormField(
                              controller: _titleCtrl,
                              label: "Título do projeto",
                              icon: Icons.title,
                            ),
                            const SizedBox(height: 12),
                            DellalioFormField(
                              controller: _taglineCtrl,
                              label: "Frase de efeito",
                              icon: Icons.short_text,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "FOTOS",
                              style: TextStyle(
                                color: panelSlateDim,
                                fontSize: 11.5,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (var i = 0; i < _photos.length; i++)
                                  _PhotoThumb(
                                    url: _photos[i],
                                    index: i,
                                    onRemove: () => _removePhoto(i),
                                  ),
                                GestureDetector(
                                  onTap: _uploadingPhoto ? null : _addPhoto,
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: inkSurface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: hairline),
                                    ),
                                    alignment: Alignment.center,
                                    child: _uploadingPhoto
                                        ? const CircularProgressIndicator(
                                            color: dellalioGold,
                                          )
                                        : Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: panelSlateDim,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 26),
                            Row(
                              children: [
                                Text(
                                  "DESTAQUES (BALÕES SOBRE AS FOTOS)",
                                  style: TextStyle(
                                    color: panelSlateDim,
                                    fontSize: 11.5,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_highlights.isEmpty)
                              const DellalioEmptyState(
                                icon: Icons.chat_bubble_outline,
                                title: "Nenhum destaque cadastrado",
                              ),
                            for (var i = 0; i < _highlights.length; i++)
                              _HighlightTile(
                                data: _highlights[i],
                                onEdit: () => _openHighlightForm(
                                  highlight: _highlights[i],
                                  index: i,
                                ),
                                onDelete: () => _removeHighlight(i),
                              ),
                            const SizedBox(height: 10),
                            DellalioGhostButton(
                              label: "Novo destaque",
                              icon: Icons.add,
                              fullWidth: true,
                              onPressed: () => _openHighlightForm(),
                            ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String url;
  final int index;
  final VoidCallback onRemove;
  const _PhotoThumb({
    required this.url,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 72,
            height: 72,
            child: url.isNotEmpty
                ? Image.network(url, fit: BoxFit.cover)
                : Container(color: inkSurfaceHover),
          ),
        ),
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$index',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _HighlightTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _HighlightTile({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final position = (data['position'] ?? 'center').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: inkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['label'] ?? '').toString(),
                  style: TextStyle(color: panelIvory, fontSize: 13.5),
                ),
                Text(
                  "${data['description'] ?? ''} · foto ${data['photoIndex'] ?? 0} · "
                  "${_positionLabels[position] ?? position}",
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

class _HighlightFormDialog extends StatefulWidget {
  final Map<String, dynamic>? highlight;
  final int photoCount;
  const _HighlightFormDialog({this.highlight, required this.photoCount});

  @override
  State<_HighlightFormDialog> createState() => _HighlightFormDialogState();
}

class _HighlightFormDialogState extends State<_HighlightFormDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _descCtrl;
  late int _photoIndex;
  late String _position;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.highlight?['label'] ?? '');
    _descCtrl = TextEditingController(
      text: widget.highlight?['description'] ?? '',
    );
    _photoIndex = (widget.highlight?['photoIndex'] as num?)?.toInt() ?? 0;
    if (_photoIndex >= widget.photoCount) _photoIndex = 0;
    _position = (widget.highlight?['position'] ?? 'center').toString();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _descCtrl.dispose();
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
            widget.highlight == null ? "Novo destaque" : "Editar destaque",
            style: TextStyle(color: panelIvory),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DellalioFormField(
                  controller: _labelCtrl,
                  label: "Rótulo (ex: Ferragens douradas)",
                  icon: Icons.label_outline,
                ),
                const SizedBox(height: 12),
                DellalioFormField(
                  controller: _descCtrl,
                  label: "Descrição",
                  icon: Icons.short_text,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _photoIndex,
                  dropdownColor: inkSurface,
                  style: TextStyle(color: panelIvory, fontSize: 13.5),
                  decoration: InputDecoration(
                    labelText: "Foto",
                    labelStyle: TextStyle(color: panelSlate, fontSize: 13),
                    filled: true,
                    fillColor: inkSurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: hairline),
                    ),
                  ),
                  items: List.generate(
                    widget.photoCount,
                    (i) => DropdownMenuItem(value: i, child: Text('Foto $i')),
                  ),
                  onChanged: (v) => setLocalState(() => _photoIndex = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _position,
                  dropdownColor: inkSurface,
                  style: TextStyle(color: panelIvory, fontSize: 13.5),
                  decoration: InputDecoration(
                    labelText: "Posição na foto",
                    labelStyle: TextStyle(color: panelSlate, fontSize: 13),
                    filled: true,
                    fillColor: inkSurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: hairline),
                    ),
                  ),
                  items: _positions
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(_positionLabels[p] ?? p),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocalState(() => _position = v!),
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
                'label': _labelCtrl.text.trim(),
                'description': _descCtrl.text.trim(),
                'photoIndex': _photoIndex,
                'position': _position,
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
