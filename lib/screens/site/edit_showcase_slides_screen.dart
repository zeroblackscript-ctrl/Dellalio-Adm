import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/dellalio_kit.dart';
import '../../core/media_upload.dart';
import '../../core/theme.dart';
import 'preview/phone_frame.dart';
import 'preview/preview_models.dart' as preview;
import 'preview/preview_slide_view.dart';

const List<String> _backgrounds = ['dark', 'light'];
const Map<String, String> _backgroundLabels = {
  'dark': 'Escuro (navy)',
  'light': 'Claro (bege)',
};

const List<String> _animations = [
  'fadeUp',
  'zoomOutPhoto',
  'staggeredCards',
  'cropInPhoto',
];
const Map<String, String> _animationLabels = {
  'fadeUp': 'Logo com fade + título subindo',
  'zoomOutPhoto': 'Foto de fundo com zoom out',
  'staggeredCards': 'Cards de material em cascata',
  'cropInPhoto': 'Foto de fundo com crop-in + CTA',
};

/// Snapshot do que hoje está fixo em `dellalio_showcase_data.dart` — usado
/// só pelo botão "Carregar dados atuais do app".
final List<Map<String, dynamic>> _currentAppDefaults = [
  {
    'id': 'capa',
    'background': 'dark',
    'eyebrow': 'DELLALIO',
    'title': 'Do seu jeito,\ncom a nossa qualidade',
    'body': null,
    'imagePath': 'assets/imagens/logo/logo ld.png',
    'animationType': 'fadeUp',
    'ctaLabel': null,
    'badge': null,
    'materialItems': [],
  },
  {
    'id': 'planejados',
    'background': 'light',
    'eyebrow': null,
    'title': 'Cada milímetro pensado\npro seu espaço',
    'body':
        'Não existe ambiente padrão. Cada projeto é desenhado a partir '
        'das medidas reais do seu imóvel, considerando iluminação, '
        'circulação e uso diário. O resultado é um móvel que parece '
        'ter nascido junto com a parede.',
    'imagePath': 'assets/imagens/ambientes/cozinha.jpg',
    'animationType': 'zoomOutPhoto',
    'ctaLabel': null,
    'badge': '100% SOB MEDIDA',
    'materialItems': [],
  },
  {
    'id': 'materiais',
    'background': 'dark',
    'eyebrow': 'MATERIAIS',
    'title': 'Trabalhamos apenas com\nprodutos nobres',
    'body':
        'Não trabalhamos com madeira — apenas MDF de alta densidade '
        'e ferragens Hardt, para o melhor resultado e qualidade.',
    'imagePath': null,
    'animationType': 'staggeredCards',
    'ctaLabel': null,
    'badge': null,
    'materialItems': [
      {
        'name': 'MDF de alta densidade',
        'description':
            'Painéis com densidade acima de 700 kg/m³. Mais resistência, '
            'melhor acabamento e zero empenamento ao longo dos anos.',
      },
      {
        'name': 'Ferragens Hardt',
        'description':
            'Corrediças, dobradiças e puxadores 100% Hardt. '
            'Precisão e durabilidade testadas para o uso diário '
            'sem folgas nem desgaste prematuro.',
      },
    ],
  },
  {
    'id': 'acabamento',
    'background': 'light',
    'eyebrow': null,
    'title': 'O detalhe que se sente\nao tocar',
    'body':
        'Cada peça passa por revisão manual antes de sair da fábrica. '
        'Cantos arredondados, superfície lixada em três grãos '
        'e verniz acetinado de alto desempenho.',
    'imagePath': 'assets/imagens/ambientes/bancada quarto.jpg',
    'animationType': 'cropInPhoto',
    'ctaLabel': 'Solicitar meu projeto',
    'badge': 'ACABAMENTO',
    'materialItems': [],
  },
];

/// Editor dos "Slides de abertura" (onboarding + "Nosso trabalho") — grava
/// em `site_content/showcase_slides` no formato `{ items: [ShowcaseSlide] }`.
///
/// Conteúdo embutível (sem Scaffold/navegação própria): [onBack] mostra a
/// seta de voltar quando embutido num shell que troca de conteúdo in-place;
/// [onDraftChanged] é chamado a cada mudança local, pra quem estiver
/// hospedando esta tela conseguir espelhar num preview ao vivo.
class EditShowcaseSlidesScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final ValueChanged<dynamic>? onDraftChanged;

  const EditShowcaseSlidesScreen({
    super.key,
    this.onBack,
    this.onDraftChanged,
  });

  @override
  State<EditShowcaseSlidesScreen> createState() =>
      _EditShowcaseSlidesScreenState();
}

class _EditShowcaseSlidesScreenState extends State<EditShowcaseSlidesScreen> {
  final _doc = FirebaseFirestore.instance
      .collection('site_content')
      .doc('showcase_slides');

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
        ).showSnackBar(const SnackBar(content: Text('Slides salvos.')));
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
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => _SlideFormScreen(slide: item)),
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

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(target, item);
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorInlineHeader(
          title: "Slides de abertura",
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
                          icon: Icons.view_carousel_outlined,
                          title: "Nenhum slide cadastrado",
                          subtitle:
                              "Carregue os dados atuais ou adicione um novo",
                        ),
                      for (var i = 0; i < _items.length; i++)
                        _SlideTile(
                          data: _items[i],
                          isFirst: i == 0,
                          isLast: i == _items.length - 1,
                          onEdit: () => _openForm(item: _items[i], index: i),
                          onDelete: () => _remove(i),
                          onMoveUp: () => _move(i, -1),
                          onMoveDown: () => _move(i, 1),
                        ),
                      const SizedBox(height: 12),
                      DellalioGoldButton(
                        label: "Novo slide",
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

class _SlideTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _SlideTile({
    required this.data,
    required this.isFirst,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final animation = (data['animationType'] ?? 'fadeUp').toString();
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
          Column(
            children: [
              IconButton(
                icon: Icon(
                  Icons.keyboard_arrow_up,
                  color: isFirst ? panelSlateDim : panelSlate,
                  size: 18,
                ),
                onPressed: isFirst ? null : onMoveUp,
              ),
              IconButton(
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: isLast ? panelSlateDim : panelSlate,
                  size: 18,
                ),
                onPressed: isLast ? null : onMoveDown,
              ),
            ],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['title'] ?? '').toString().replaceAll('\n', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: panelIvory, fontSize: 13.5),
                ),
                Text(
                  "id: ${data['id'] ?? ''} · ${_animationLabels[animation] ?? animation}",
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

class _SlideFormScreen extends StatefulWidget {
  final Map<String, dynamic>? slide;
  const _SlideFormScreen({this.slide});

  @override
  State<_SlideFormScreen> createState() => _SlideFormScreenState();
}

class _SlideFormScreenState extends State<_SlideFormScreen> {
  late final TextEditingController _idCtrl;
  late final TextEditingController _eyebrowCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _ctaCtrl;
  late final TextEditingController _badgeCtrl;
  late String _background;
  late String _animation;
  String? _imagePath;
  Uint8List? _newImageBytes;
  bool _uploading = false;
  late List<Map<String, dynamic>> _materialItems;

  @override
  void initState() {
    super.initState();
    final s = widget.slide;
    _idCtrl = TextEditingController(text: s?['id'] ?? '');
    _eyebrowCtrl = TextEditingController(text: s?['eyebrow'] ?? '');
    _titleCtrl = TextEditingController(text: s?['title'] ?? '');
    _bodyCtrl = TextEditingController(text: s?['body'] ?? '');
    _ctaCtrl = TextEditingController(text: s?['ctaLabel'] ?? '');
    _badgeCtrl = TextEditingController(text: s?['badge'] ?? '');
    _background = (s?['background'] ?? 'dark').toString();
    _animation = (s?['animationType'] ?? 'fadeUp').toString();
    _imagePath = s?['imagePath'] as String?;
    _materialItems = (s?['materialItems'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    // Refaz o preview a cada tecla digitada.
    for (final c in [
      _idCtrl,
      _eyebrowCtrl,
      _titleCtrl,
      _bodyCtrl,
      _ctaCtrl,
      _badgeCtrl,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  Map<String, dynamic> _currentSlideMap() => {
    'id': _idCtrl.text.trim(),
    'background': _background,
    'eyebrow': _eyebrowCtrl.text.trim().isEmpty ? null : _eyebrowCtrl.text.trim(),
    'title': _titleCtrl.text,
    'body': _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
    'imagePath': _imagePath,
    'animationType': _animation,
    'ctaLabel': _ctaCtrl.text.trim().isEmpty ? null : _ctaCtrl.text.trim(),
    'badge': _badgeCtrl.text.trim().isEmpty ? null : _badgeCtrl.text.trim(),
    'materialItems': _materialItems,
  };

  @override
  void dispose() {
    _idCtrl.dispose();
    _eyebrowCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _ctaCtrl.dispose();
    _badgeCtrl.dispose();
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
      final url = await uploadSiteContentMedia(bytes, 'showcase_slides');
      if (mounted) setState(() => _imagePath = url);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openMaterialItemForm({
    Map<String, dynamic>? item,
    int? index,
  }) async {
    final nameCtrl = TextEditingController(text: item?['name'] ?? '');
    final descCtrl = TextEditingController(text: item?['description'] ?? '');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: inkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(
          item == null ? "Novo material" : "Editar material",
          style: TextStyle(color: panelIvory),
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DellalioFormField(
                controller: nameCtrl,
                label: "Nome",
                icon: Icons.label_outline,
              ),
              const SizedBox(height: 12),
              DellalioFormField(
                controller: descCtrl,
                label: "Descrição",
                icon: Icons.short_text,
                maxLines: 3,
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
              'name': nameCtrl.text.trim(),
              'description': descCtrl.text.trim(),
            }),
            child: const Text("Salvar", style: TextStyle(color: dellalioGold)),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _materialItems[index] = result;
      } else {
        _materialItems.add(result);
      }
    });
  }

  void _saveAndReturn() => Navigator.pop(context, _currentSlideMap());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: Column(
        children: [
          DellalioSubHeader(
            title: widget.slide == null ? "Novo slide" : "Editar slide",
            trailing: DellalioGoldButton(
              label: "Salvar",
              icon: Icons.check,
              onPressed: _saveAndReturn,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      DellalioFormField(
                        controller: _idCtrl,
                        label: "Identificador (ex: capa, materiais)",
                        icon: Icons.tag,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _background,
                        dropdownColor: inkSurface,
                        style: TextStyle(color: panelIvory, fontSize: 13.5),
                        decoration: InputDecoration(
                          labelText: "Fundo",
                          labelStyle: TextStyle(
                            color: panelSlate,
                            fontSize: 13,
                          ),
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
                        items: _backgrounds
                            .map(
                              (b) => DropdownMenuItem(
                                value: b,
                                child: Text(_backgroundLabels[b] ?? b),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _background = v!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _animation,
                        dropdownColor: inkSurface,
                        style: TextStyle(color: panelIvory, fontSize: 13.5),
                        decoration: InputDecoration(
                          labelText: "Animação de entrada",
                          labelStyle: TextStyle(
                            color: panelSlate,
                            fontSize: 13,
                          ),
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
                        items: _animations
                            .map(
                              (a) => DropdownMenuItem(
                                value: a,
                                child: Text(
                                  _animationLabels[a] ?? a,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _animation = v!),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "IMAGEM DE FUNDO / LOGO (opcional)",
                        style: TextStyle(
                          color: panelSlateDim,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _uploading ? null : _pickImage,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 140,
                            width: double.infinity,
                            child: _uploading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: dellalioGold,
                                    ),
                                  )
                                : _newImageBytes != null
                                ? Image.memory(
                                    _newImageBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : (_imagePath != null &&
                                          _imagePath!.isNotEmpty &&
                                          !_imagePath!.startsWith('assets/'))
                                ? Image.network(_imagePath!, fit: BoxFit.cover)
                                : Container(
                                    color: inkSurface,
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          color: panelSlateDim,
                                        ),
                                        if (_imagePath != null &&
                                            _imagePath!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              _imagePath!,
                                              style: TextStyle(
                                                color: panelSlateDim,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DellalioFormField(
                        controller: _eyebrowCtrl,
                        label: "Eyebrow (rótulo pequeno acima do título)",
                        icon: Icons.short_text,
                      ),
                      const SizedBox(height: 12),
                      DellalioFormField(
                        controller: _badgeCtrl,
                        label: "Badge (selo, ex: 100% SOB MEDIDA)",
                        icon: Icons.workspace_premium_outlined,
                      ),
                      const SizedBox(height: 12),
                      DellalioFormField(
                        controller: _titleCtrl,
                        label: "Título (use \\n para quebrar linha)",
                        icon: Icons.title,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      DellalioFormField(
                        controller: _bodyCtrl,
                        label: "Texto de apoio (opcional)",
                        icon: Icons.notes,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      DellalioFormField(
                        controller: _ctaCtrl,
                        label: "Texto do botão de ação (opcional)",
                        icon: Icons.touch_app_outlined,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "CARDS DE MATERIAL (usados na animação 'staggeredCards')",
                        style: TextStyle(
                          color: panelSlateDim,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _materialItems.length; i++)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: inkSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: hairline),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (_materialItems[i]['name'] ?? '')
                                          .toString(),
                                      style: TextStyle(
                                        color: panelIvory,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      (_materialItems[i]['description'] ?? '')
                                          .toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: panelSlateDim,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: panelSlate,
                                  size: 16,
                                ),
                                onPressed: () => _openMaterialItemForm(
                                  item: _materialItems[i],
                                  index: i,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: panelRust,
                                  size: 16,
                                ),
                                onPressed: () => setState(
                                  () => _materialItems.removeAt(i),
                                ),
                              ),
                            ],
                          ),
                        ),
                      DellalioGhostButton(
                        label: "Novo card de material",
                        icon: Icons.add,
                        fullWidth: true,
                        onPressed: () => _openMaterialItemForm(),
                      ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    color: inkSurface,
                    padding: const EdgeInsets.all(16),
                    child: PhoneFrame(
                      child: PreviewSlideView(
                        isActive: true,
                        slide: preview.ShowcaseSlide.fromMap(
                          _currentSlideMap(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
