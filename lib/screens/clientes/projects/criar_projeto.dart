import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../../core/dellalio_kit.dart';
import '../../../core/theme.dart';

class CreateProjectScreen extends StatefulWidget {
  final String clientId;

  const CreateProjectScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _projectNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _valorController = TextEditingController();
  final _customEnvironmentController = TextEditingController();

  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();

  DateTime? _deliveryDate;
  String? _currentStatus = 'conferencia';
  String _selectedEnvironment = 'Sala';
  String _selectedColorHex = '#00695C';

  final List<Map<String, dynamic>> _files = [];
  final List<String> _galleryUrls = [];

  final _phoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _isLoading = false;
  bool _initialized = false;

  final List<String> _environmentOptions = [
    'Sala',
    'Cozinha',
    'Quarto',
    'Banheiro',
    'Outro',
  ];

  final List<String> _statusOptions = [
    'conferencia',
    'pedido',
    'producao',
    'entrega',
    'montagem',
    'finalizado',
  ];

  @override
  void dispose() {
    _projectNameController.dispose();
    _notesController.dispose();
    _valorController.dispose();
    _customEnvironmentController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    super.dispose();
  }

  void _initializeClientData(Map<String, dynamic> cData) {
    if (_initialized) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clientNameController.text = cData['name'] ?? '';
      _clientPhoneController.text =
          _phoneFormatter.maskText(cData['phone'] ?? '');
      _deliveryDate = DateTime.now();

      setState(() {
        _initialized = true;
      });
    });
  }

  Future<void> _uploadAndAddFile(String type) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: type == 'pdf' ? FileType.custom : FileType.image,
      allowedExtensions: type == 'pdf' ? ['pdf'] : null,
      withData: true,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _isLoading = true);

    for (var file in result.files) {
      if (file.bytes == null) continue;

      final String fileName = file.name;

      try {
        final bytes = file.bytes!;
        final ref = FirebaseStorage.instance.ref().child(
              '${type}s/${DateTime.now().millisecondsSinceEpoch}_$fileName',
            );
        await ref.putData(bytes);
        final url = await ref.getDownloadURL();

        setState(() {
          if (type == 'pdf') {
            _files.add({'name': fileName, 'url': url});
          } else {
            _galleryUrls.add(url);
          }
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ERRO AO SUBIR ARQUIVO: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _deleteFile(String type, dynamic fileData) async {
    try {
      final url = fileData is Map ? fileData['url'] : fileData;
      await FirebaseStorage.instance.refFromURL(url).delete();

      setState(() {
        if (type == 'pdf') {
          _files.remove(fileData);
        } else {
          _galleryUrls.remove(fileData);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ERRO AO DELETAR: $e')),
      );
    }
  }

  Future<void> _saveNewProject() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference clientRef = FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId);

      String phoneRaw = _phoneFormatter.getUnmaskedText();
      if (phoneRaw.isEmpty) {
        phoneRaw =
            _clientPhoneController.text.replaceAll(RegExp(r'\D'), '');
      }

      batch.update(clientRef, {
        'name': _clientNameController.text.trim(),
        'phone': phoneRaw,
      });

      final environmentFinal = _selectedEnvironment == 'Outro'
          ? _customEnvironmentController.text.trim()
          : _selectedEnvironment;

      DocumentReference projectRef = FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('projects')
          .doc();

      batch.set(projectRef, {
        'projectName': _projectNameController.text.trim(),
        'environment': environmentFinal,
        'notes': _notesController.text.trim(),
        'valor':
            double.tryParse(_valorController.text.replaceAll(',', '.')) ??
                0.0,
        'status': _currentStatus,
        'deliveryDate':
            _deliveryDate != null ? Timestamp.fromDate(_deliveryDate!) : null,
        'files': _files,
        'galleryUrls': _galleryUrls,
        'corProjeto': _selectedColorHex,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PROJETO CRIADO COM SUCESSO!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ERRO AO SALVAR PROJETO: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .snapshots(),
      builder: (context, cSnap) {
        if (!cSnap.hasData || !cSnap.data!.exists) {
          return Scaffold(
            backgroundColor: inkPageBg,
            body: const Center(child: CircularProgressIndicator(color: dellalioGold)),
          );
        }

        final cData = cSnap.data!.data() as Map<String, dynamic>;
        _initializeClientData(cData);

        if (!_initialized) {
          return Scaffold(
            backgroundColor: inkPageBg,
            body: const Center(child: CircularProgressIndicator(color: dellalioGold)),
          );
        }

        final String statusToUse = _statusOptions.contains(_currentStatus)
            ? _currentStatus!
            : 'conferencia';

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: inkPageBg,
          body: Column(
            children: [
              const DellalioSubHeader(title: "Criar novo projeto"),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Cliente (info básica)",
                              style: TextStyle(
                                  color: dellalioLabel,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                  child: _buildTextField(
                                      _clientNameController,
                                      'NOME DO CLIENTE')),
                              const SizedBox(width: 15),
                              Expanded(
                                  child: _buildTextField(
                                      _clientPhoneController,
                                      'TELEFONE',
                                      formatters: [_phoneFormatter])),
                            ],
                          ),
                          const SizedBox(height: 25),
                          Text("Detalhes do projeto",
                              style: TextStyle(
                                  color: dellalioLabel,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          const SizedBox(height: 10),
                          _buildTextField(
                              _projectNameController, 'NOME DO PROJETO'),

                          // Seletor de cor do projeto
                          const SizedBox(height: 8),
                          Text("Cor do card do projeto",
                              style: TextStyle(
                                  color: panelSlate,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          const SizedBox(height: 6),
                          _buildColorPicker(),
                          const SizedBox(height: 12),

                          Container(
                            margin:
                                const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                                color: inkSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: hairline)),
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedEnvironment,
                              dropdownColor: inkSurface,
                              style: TextStyle(color: panelIvory, fontSize: 13.5),
                              decoration: InputDecoration(
                                labelText: 'Ambiente do projeto',
                                labelStyle: TextStyle(
                                    color: panelSlate, fontSize: 13),
                                border: InputBorder.none,
                              ),
                              items: _environmentOptions
                                  .map((String env) {
                                return DropdownMenuItem<String>(
                                    value: env, child: Text(env));
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() =>
                                      _selectedEnvironment = value);
                                }
                              },
                            ),
                          ),
                          if (_selectedEnvironment == 'Outro')
                            _buildTextField(_customEnvironmentController,
                                'DIGITE O NOME DO NOVO AMBIENTE'),

                          _buildTextField(_notesController, 'OBSERVAÇÕES',
                              maxLines: 2),

                          Row(
                            children: [
                              Expanded(
                                  child: _buildTextField(
                                      _valorController,
                                      'VALOR DO PROJETO',
                                      keyboardType: const TextInputType
                                          .numberWithOptions(
                                          decimal: true))),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Container(
                                  height: 60,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                      color: inkSurface,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(color: hairline)),
                                  child: _buildDateTile(
                                      'ENTREGA',
                                      _deliveryDate,
                                      (d) => setState(
                                          () => _deliveryDate = d)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          DropdownButtonFormField<String>(
                            initialValue: statusToUse,
                            decoration: InputDecoration(
                              labelText: 'Status do projeto',
                              labelStyle: TextStyle(
                                  color: panelSlate, fontSize: 13),
                              filled: true,
                              fillColor: inkSurface,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                      Radius.circular(8))),
                            ),
                            dropdownColor: inkSurface,
                            style: TextStyle(color: panelIvory, fontSize: 13.5),
                            items: const [
                              DropdownMenuItem(
                                  value: 'conferencia',
                                  child: Text('CONFERÊNCIA')),
                              DropdownMenuItem(
                                  value: 'pedido',
                                  child: Text('PEDIDO')),
                              DropdownMenuItem(
                                  value: 'producao',
                                  child: Text('PRODUÇÃO')),
                              DropdownMenuItem(
                                  value: 'entrega',
                                  child: Text('ENTREGA')),
                              DropdownMenuItem(
                                  value: 'montagem',
                                  child: Text('MONTAGEM')),
                              DropdownMenuItem(
                                  value: 'finalizado',
                                  child: Text('FINALIZADO')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(
                                    () => _currentStatus = value);
                              }
                            },
                          ),
                          const SizedBox(height: 30),
                          const Divider(color: Colors.grey),
                          const SizedBox(height: 10),

                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ExpansionTile(
                                  initiallyExpanded: true,
                                  iconColor: Colors.red,
                                  leading: const Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.red),
                                  title: const Text("DOCUMENTOS PDF",
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold)),
                                  children: [
                                    _buildLocalFileGrid(_files, 'pdf',
                                        Icons.picture_as_pdf, Colors.red),
                                    TextButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: const Text("ADICIONAR PDF"),
                                      onPressed: _isLoading
                                          ? null
                                          : () =>
                                              _uploadAndAddFile('pdf'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: ExpansionTile(
                                  initiallyExpanded: true,
                                  iconColor: Colors.blue,
                                  leading: const Icon(Icons.image,
                                      color: Colors.blue),
                                  title: const Text("GALERIA DE FOTOS",
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold)),
                                  children: [
                                    _buildLocalFileGrid(_galleryUrls,
                                        'image', Icons.image, Colors.blue),
                                    TextButton.icon(
                                      icon: const Icon(Icons.add),
                                      label:
                                          const Text("ADICIONAR FOTO"),
                                      onPressed: _isLoading
                                          ? null
                                          : () => _uploadAndAddFile(
                                              'image'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: hairline)),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: dellalioGold))
                : DellalioGoldButton(
                    label: "Criar projeto",
                    icon: Icons.add,
                    fullWidth: true,
                    onPressed: _saveNewProject,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DellalioTheme.projectColors.map((colorOption) {
        final Color cor = colorOption['color'] as Color;
        final String hex = colorOption['hex'] as String;
        final String label = colorOption['label'] as String;
        final bool selected = _selectedColorHex == hex;

        return GestureDetector(
          onTap: () => setState(() => _selectedColorHex = hex),
          child: Tooltip(
            message: label,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: cor.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1)
                      ]
                    : null,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    List<TextInputFormatter>? formatters,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return DellalioFormField(
      controller: controller,
      label: label,
      inputFormatters: formatters,
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  Widget _buildDateTile(String label, DateTime? dateValue,
      Function(DateTime) onDateSelected) {
    String formattedDate = dateValue != null
        ? "${dateValue.day.toString().padLeft(2, '0')}/${dateValue.month.toString().padLeft(2, '0')}/${dateValue.year}"
        : 'SELECIONAR';

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(label,
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 12, color: panelSlate)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formattedDate,
              style: TextStyle(fontSize: 12, color: panelIvory)),
          const Icon(Icons.calendar_today,
              size: 16, color: dellalioGold),
        ],
      ),
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: dateValue ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onDateSelected(picked);
      },
    );
  }

  Widget _buildLocalFileGrid(
      List<dynamic> items, String type, IconData icon, Color color) {
    if (items.isEmpty) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        child: Text("Nenhum arquivo",
            style: TextStyle(
                color: panelSlateDim, fontSize: 12)),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10),
      gridDelegate:
          const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 2.5,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final dynamic f = items[i];
        final String name = (f is Map)
            ? (f['name']?.toString() ?? 'ARQUIVO')
            : 'FOTO ${i + 1}';

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: hairline),
            borderRadius: BorderRadius.circular(4),
            color: inkSurface,
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              title: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10, color: panelIvory)),
              trailing: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.delete, size: 14, color: color),
                onPressed: _isLoading
                    ? null
                    : () => _deleteFile(type, f),
              ),
            ),
          ),
        );
      },
    );
  }
}
