import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/dellalio_kit.dart';
import '../../core/media_upload.dart';
import '../../core/theme.dart';

/// Editor da vitrine "Vídeo de destaque" — grava em
/// `site_content/showcase_video` no formato `{ videoUrl, title, subtitle }`.
///
/// Conteúdo embutível (sem Scaffold/navegação própria): [onBack] mostra a
/// seta de voltar quando embutido num shell que troca de conteúdo in-place;
/// [onDraftChanged] é chamado a cada mudança local, pra quem estiver
/// hospedando esta tela conseguir espelhar num preview ao vivo.
class EditShowcaseVideoScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final ValueChanged<dynamic>? onDraftChanged;

  const EditShowcaseVideoScreen({
    super.key,
    this.onBack,
    this.onDraftChanged,
  });

  @override
  State<EditShowcaseVideoScreen> createState() =>
      _EditShowcaseVideoScreenState();
}

class _EditShowcaseVideoScreenState extends State<EditShowcaseVideoScreen> {
  final _doc = FirebaseFirestore.instance
      .collection('site_content')
      .doc('showcase_video');

  late final TextEditingController _urlCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _subtitleCtrl;

  bool _loading = true;
  bool _docExists = false;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
    _titleCtrl = TextEditingController();
    _subtitleCtrl = TextEditingController();
    // Refaz o preview a cada tecla digitada.
    for (final c in [_urlCtrl, _titleCtrl, _subtitleCtrl]) {
      c.addListener(() {
        setState(() {});
        _notify();
      });
    }
    _load();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  void _notify() => widget.onDraftChanged?.call({
    'videoUrl': _urlCtrl.text.trim(),
    'title': _titleCtrl.text,
    'subtitle': _subtitleCtrl.text,
  });

  Future<void> _load() async {
    final snap = await _doc.get();
    final data = snap.data();
    setState(() {
      _docExists = snap.exists;
      _urlCtrl.text = data?['videoUrl'] as String? ?? '';
      _titleCtrl.text = data?['title'] as String? ?? '';
      _subtitleCtrl.text = data?['subtitle'] as String? ?? '';
      _loading = false;
    });
  }

  void _seedFromApp() {
    setState(() {
      _urlCtrl.text = 'assets/videos/snapinsta-1787241165654.mp4';
      _titleCtrl.text = 'Cozinha planejada entregue';
      _subtitleCtrl.text = 'Cozinha · São Paulo';
    });
  }

  Future<void> _pickVideo() async {
    final bytes = await pickVideoBytes();
    if (bytes == null) return;
    setState(() => _uploading = true);
    try {
      final url = await uploadSiteContentMedia(
        bytes,
        'showcase_video',
        ext: 'mp4',
      );
      if (mounted) setState(() => _urlCtrl.text = url);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _doc.set({
        'videoUrl': _urlCtrl.text.trim(),
        'title': _titleCtrl.text.trim(),
        'subtitle': _subtitleCtrl.text.trim(),
      });
      if (mounted) {
        setState(() => _docExists = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Vídeo salvo.')));
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
          title: "Vídeo de destaque",
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
                        controller: _urlCtrl,
                        label: "URL do vídeo",
                        icon: Icons.link,
                      ),
                      const SizedBox(height: 10),
                      DellalioGhostButton(
                        label: _uploading ? "Enviando..." : "Enviar novo vídeo",
                        icon: Icons.upload_outlined,
                        onPressed: _uploading ? () {} : _pickVideo,
                      ),
                      const SizedBox(height: 20),
                      DellalioFormField(
                        controller: _titleCtrl,
                        label: "Título",
                        icon: Icons.title,
                      ),
                      const SizedBox(height: 12),
                      DellalioFormField(
                        controller: _subtitleCtrl,
                        label: "Subtítulo",
                        icon: Icons.short_text,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
