import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/dellalio_kit.dart';
import '../../core/media_upload.dart';
import '../../core/theme.dart';

/// Editor da vitrine "Antes e depois" — grava em `site_content/before_after`
/// no formato `{ items: [{beforeImageUrl, afterImageUrl}] }` (o app cliente
/// usa `items.first`).
///
/// Conteúdo embutível (sem Scaffold/navegação própria): [onBack] mostra a
/// seta de voltar quando embutido num shell que troca de conteúdo in-place;
/// [onDraftChanged] é chamado a cada mudança local, pra quem estiver
/// hospedando esta tela conseguir espelhar num preview ao vivo.
class EditBeforeAfterScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final ValueChanged<dynamic>? onDraftChanged;

  const EditBeforeAfterScreen({super.key, this.onBack, this.onDraftChanged});

  @override
  State<EditBeforeAfterScreen> createState() => _EditBeforeAfterScreenState();
}

class _EditBeforeAfterScreenState extends State<EditBeforeAfterScreen> {
  final _doc = FirebaseFirestore.instance
      .collection('site_content')
      .doc('before_after');

  String? _beforeUrl;
  String? _afterUrl;
  Uint8List? _newBeforeBytes;
  Uint8List? _newAfterBytes;
  bool _uploadingBefore = false;
  bool _uploadingAfter = false;
  bool _loading = true;
  bool _docExists = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _notify() => widget.onDraftChanged?.call({
    'beforeImageUrl': _beforeUrl,
    'afterImageUrl': _afterUrl,
  });

  Future<void> _load() async {
    final snap = await _doc.get();
    final items = snap.data()?['items'] as List?;
    final first = (items != null && items.isNotEmpty)
        ? Map<String, dynamic>.from(items.first)
        : null;
    setState(() {
      _docExists = snap.exists;
      _beforeUrl = first?['beforeImageUrl'] as String?;
      _afterUrl = first?['afterImageUrl'] as String?;
      _loading = false;
    });
    _notify();
  }

  void _seedFromApp() {
    setState(() {
      _beforeUrl = 'assets/imagens/ambientes/antes aline.jpeg';
      _afterUrl = 'assets/imagens/ambientes/depois aline.jpeg';
    });
    _notify();
  }

  Future<void> _pickBefore() async {
    final bytes = await pickImageBytes();
    if (bytes == null) return;
    setState(() {
      _newBeforeBytes = bytes;
      _uploadingBefore = true;
    });
    try {
      final url = await uploadSiteContentMedia(bytes, 'before_after');
      if (mounted) setState(() => _beforeUrl = url);
      _notify();
    } finally {
      if (mounted) setState(() => _uploadingBefore = false);
    }
  }

  Future<void> _pickAfter() async {
    final bytes = await pickImageBytes();
    if (bytes == null) return;
    setState(() {
      _newAfterBytes = bytes;
      _uploadingAfter = true;
    });
    try {
      final url = await uploadSiteContentMedia(bytes, 'before_after');
      if (mounted) setState(() => _afterUrl = url);
      _notify();
    } finally {
      if (mounted) setState(() => _uploadingAfter = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _doc.set({
        'items': [
          {'beforeImageUrl': _beforeUrl, 'afterImageUrl': _afterUrl},
        ],
      });
      if (mounted) {
        setState(() => _docExists = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Antes e depois salvos.')),
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

  Widget _imageSlot({
    required String label,
    required String? url,
    required Uint8List? newBytes,
    required bool uploading,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(color: panelSlate, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: uploading ? null : onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: uploading
                    ? const Center(
                        child: CircularProgressIndicator(color: dellalioGold),
                      )
                    : newBytes != null
                    ? Image.memory(newBytes, fit: BoxFit.cover)
                    : (url != null && url.isNotEmpty)
                    ? Image.network(url, fit: BoxFit.cover)
                    : Container(
                        color: inkSurface,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: panelSlateDim,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorInlineHeader(
          title: "Antes e depois",
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _imageSlot(
                            label: "ANTES",
                            url: _beforeUrl,
                            newBytes: _newBeforeBytes,
                            uploading: _uploadingBefore,
                            onTap: _pickBefore,
                          ),
                          const SizedBox(width: 16),
                          _imageSlot(
                            label: "DEPOIS",
                            url: _afterUrl,
                            newBytes: _newAfterBytes,
                            uploading: _uploadingAfter,
                            onTap: _pickAfter,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
