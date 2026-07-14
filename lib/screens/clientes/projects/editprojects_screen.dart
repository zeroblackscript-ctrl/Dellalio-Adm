import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class EditProjectScreen extends StatefulWidget {
  final String clientId;
  final String projectId;

  const EditProjectScreen({
    super.key,
    required this.clientId,
    required this.projectId,
  });

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Controllers for Project Data
  final _projectNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _valorController = TextEditingController();

  // Controllers adicionados para os dados vindos do Orçamento
  final _ambienteController = TextEditingController();
  final _materiaisController = TextEditingController();
  final _formaPagamentoController = TextEditingController();

  // Controllers das Especificações Técnicas (vindas do orçamento)
  final _corCaixaController = TextEditingController();
  final _valorCaixaController = TextEditingController();
  final _corAcabController = TextEditingController();
  final _valorAcabController = TextEditingController();

  // Lista dinâmica de Extras: cada item = {'nome': TextEditingController, 'valor': TextEditingController}
  final List<Map<String, TextEditingController>> _extras = [];

  // Controllers for basic Client Info
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();

  // Controllers de Endereço da Obra (pode ser diferente do endereço do cliente)
  final _cepController = TextEditingController();
  final _addressController = TextEditingController();
  final _numberController = TextEditingController();
  final _numberFocusNode = FocusNode();

  // Date states
  DateTime? _deliveryDate;

  // Mask Formatters
  final _phoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final _cepFormatter = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _isLoading = false;
  bool _isSearchingCep = false;

  bool _initialized = false;
  String? _currentStatus;

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
    _ambienteController.dispose();
    _materiaisController.dispose();
    _formaPagamentoController.dispose();
    _corCaixaController.dispose();
    _valorCaixaController.dispose();
    _corAcabController.dispose();
    _valorAcabController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _cepController.dispose();
    _addressController.dispose();
    _numberController.dispose();
    _numberFocusNode.dispose();
    for (var e in _extras) {
      e['nome']?.dispose();
      e['valor']?.dispose();
    }
    super.dispose();
  }

  // --- Helper de Busca de CEP (ViaCEP) ---

  Future<void> _buscarEnderecoPorCep(String cep) async {
    final cleanCep = cep.replaceAll(RegExp(r'\D'), '');
    if (cleanCep.length != 8) return;

    setState(() => _isSearchingCep = true);

    try {
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$cleanCep/json/'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('erro')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CEP não encontrado')),
          );
          return;
        }

        if (!mounted) return;
        setState(() {
          _addressController.text =
              "${data['logradouro']}, ${data['bairro']} - ${data['localidade']}/${data['uf']}";
        });

        // Move o foco para o campo de Número automaticamente
        FocusScope.of(context).requestFocus(_numberFocusNode);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao buscar CEP')),
      );
    } finally {
      if (mounted) setState(() => _isSearchingCep = false);
    }
  }

  // --- Helpers de Parsing/Formatação Monetária ---

  double _parseMoney(String value) {
    if (value.trim().isEmpty) return 0.0;
    return double.tryParse(value.replaceAll('.', '').replaceAll(',', '.')) ??
        double.tryParse(value.replaceAll(',', '.')) ??
        0.0;
  }

  String _formatMoney(dynamic value) {
    final double v = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0.0;
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }


  double _calcularTotal() {
    double total = _parseMoney(_valorCaixaController.text) + _parseMoney(_valorAcabController.text);
    for (var e in _extras) {
      total += _parseMoney(e['valor']!.text);
    }
    return total;
  }

  void _atualizarValorTotal() {
    setState(() {
      _valorController.text = _calcularTotal().toStringAsFixed(2).replaceAll('.', ',');
    });
  }

  void _adicionarExtra() {
    setState(() {
      _extras.add({
        'nome': TextEditingController(),
        'valor': TextEditingController(text: '0,00'),
      });
    });
  }

  void _removerExtra(int index) {
    setState(() {
      _extras[index]['nome']?.dispose();
      _extras[index]['valor']?.dispose();
      _extras.removeAt(index);
    });
    _atualizarValorTotal();
  }

  // --- Core Methods: Loading Data ---

  void _initializeData(Map<String, dynamic> cData, Map<String, dynamic> pData) {
    if (_initialized) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Load Project Data
      _projectNameController.text = pData['projectName'] ?? pData['nome'] ?? '';
      _notesController.text = pData['notes'] ?? '';
      _currentStatus = pData['status'] ?? 'conferencia';

      // Load Orçamento Data (compatibilidade)
      _ambienteController.text = pData['ambiente'] ?? pData['environment'] ?? '';
      _materiaisController.text = pData['materiais'] ?? '';
      _formaPagamentoController.text = pData['formaPagamento'] ?? '';

      // Especificações Técnicas vindas do orçamento
      _corCaixaController.text = pData['corCaixa']?.toString() ?? '';
      _valorCaixaController.text = _formatMoney(pData['valorCaixa'] ?? 0);
      _corAcabController.text = pData['corAcab']?.toString() ?? '';
      _valorAcabController.text = _formatMoney(pData['valorAcab'] ?? 0);

      // Extras (lista de {nome/desc, valor})
      final List extrasSalvos = pData['extras'] ?? [];
      _extras.clear();
      for (var ex in extrasSalvos) {
        final Map extMap = ex as Map;
        _extras.add({
          'nome': TextEditingController(text: (extMap['nome'] ?? extMap['desc'] ?? '').toString()),
          'valor': TextEditingController(text: _formatMoney(extMap['valor'] ?? 0)),
        });
      }

      // Valor total: usa 'valor' salvo, ou recalcula se não existir
      if (pData['valor'] != null) {
        _valorController.text = _formatMoney(pData['valor']);
      } else if (pData['valorTotal'] != null) {
        _valorController.text = _formatMoney(pData['valorTotal']);
      } else {
        _valorController.text = _calcularTotal().toStringAsFixed(2).replaceAll('.', ',');
      }

      // Load Client Data
      _clientNameController.text = cData['name'] ?? '';
      _clientPhoneController.text = _phoneFormatter.maskText(cData['phone'] ?? '');

      // Load Endereço da Obra (endereço do projeto, independente do endereço do cliente)
      _cepController.text = pData['cep']?.toString() ?? '';
      _addressController.text = pData['address']?.toString() ?? '';
      _numberController.text = pData['addressNumber']?.toString() ?? '';

      // Load Dates
      _deliveryDate = (pData['deliveryDate'] as Timestamp?)?.toDate();

      setState(() {
        _initialized = true;
      });
    });
  }


  // --- Core Methods: Saving Data ---

  Future<void> _saveAllChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Update Client
      DocumentReference clientRef = FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId);

      String phoneRaw = _phoneFormatter.getUnmaskedText();
      if (phoneRaw.isEmpty) {
        phoneRaw = _clientPhoneController.text.replaceAll(RegExp(r'\D'), '');
      }

      batch.update(clientRef, {
        'name': _clientNameController.text.trim(),
        'phone': phoneRaw,
      });

      // 2. Update Project
      DocumentReference projectRef = FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('projects')
          .doc(widget.projectId);

      final List<Map<String, dynamic>> extrasFormatados = _extras.map((e) {
        return {
          'nome': e['nome']!.text.trim(),
          'valor': _parseMoney(e['valor']!.text),
        };
      }).toList();

      final String numero = _numberController.text.trim();
      final String enderecoBase = _addressController.text.trim();
      final String enderecoCompleto = enderecoBase.isEmpty
          ? ''
          : (numero.isEmpty ? enderecoBase : "$enderecoBase, N° $numero");

      batch.update(projectRef, {
        'projectName': _projectNameController.text.trim(),
        'notes': _notesController.text.trim(),
        'valor': _parseMoney(_valorController.text),
        'valorTotal': _parseMoney(_valorController.text),
        'status': _currentStatus,
        'deliveryDate': _deliveryDate != null ? Timestamp.fromDate(_deliveryDate!) : null,

        // Endereço da Obra (independente do endereço do cliente)
        'cep': _cepController.text.trim(),
        'address': enderecoCompleto,
        'addressNumber': numero,

        // Dados do Orçamento
        'ambiente': _ambienteController.text.trim(),
        'materiais': _materiaisController.text.trim(),
        'formaPagamento': _formaPagamentoController.text.trim(),

        // Especificações Técnicas
        'corCaixa': _corCaixaController.text.trim(),
        'valorCaixa': _parseMoney(_valorCaixaController.text),
        'corAcab': _corAcabController.text.trim(),
        'valorAcab': _parseMoney(_valorAcabController.text),
        'extras': extrasFormatados,
      });


      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projeto atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Core Methods: File Management (Suporte a múltiplos arquivos) ---

  /// Faz upload de múltiplos arquivos (PDFs ou imagens) de uma vez e
  /// adiciona todos no array [fieldName] do documento do projeto.
  ///
  /// [fieldName] pode ser: 'files' (Orçamentos em PDF), 'contratos' (Contratos em PDF)
  /// ou 'galleryUrls' (Fotos).
  Future<void> _uploadAndAddFiles(String type, String fieldName) async {
    // 1. Permite seleção múltipla de arquivos
    FilePickerResult? result = await FilePicker.pickFiles(
      type: type == 'pdf' ? FileType.custom : FileType.image,
      allowedExtensions: type == 'pdf' ? ['pdf'] : null,
      withData: true,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      List<dynamic> novosArquivos = [];

      // 2. Loop para fazer upload de todos os arquivos selecionados
      for (var file in result.files) {
        if (file.bytes == null) continue;

        final String fileName = file.name;
        final ref = FirebaseStorage.instance.ref().child(
              '$fieldName/${DateTime.now().millisecondsSinceEpoch}_$fileName',
            );

        await ref.putData(file.bytes!);
        final url = await ref.getDownloadURL();

        novosArquivos.add(
          type == 'pdf' ? {'name': fileName, 'url': url} : url,
        );
      }

      // 3. Salva todos no Firestore de uma vez, usando arrayUnion
      if (novosArquivos.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('projects')
            .doc(widget.projectId)
            .update({
          fieldName: FieldValue.arrayUnion(novosArquivos),
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao subir arquivo(s): $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFile(String fieldName, dynamic fileData) async {
    try {
      final url = fileData is Map ? fileData['url'] : fileData;
      await FirebaseStorage.instance.refFromURL(url).delete();
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('projects')
          .doc(widget.projectId)
          .update({
            fieldName: FieldValue.arrayRemove([fileData]),
          });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao deletar: $e')));
    }
  }

  // --- The UI ---

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('clients').doc(widget.clientId).snapshots(),
      builder: (context, cSnap) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clients')
              .doc(widget.clientId)
              .collection('projects')
              .doc(widget.projectId)
              .snapshots(),
          builder: (context, pSnap) {
            if (!cSnap.hasData || !pSnap.hasData || !cSnap.data!.exists || !pSnap.data!.exists) {
              return Scaffold(
                backgroundColor: const Color.fromARGB(255, 123, 123, 123),
                appBar: AppBar(backgroundColor: const Color.fromARGB(255, 98, 80, 63)),
                body: const Center(child: CircularProgressIndicator(color: Colors.white)),
              );
            }

            final cData = cSnap.data!.data() as Map<String, dynamic>;
            final pData = pSnap.data!.data() as Map<String, dynamic>;

            _initializeData(cData, pData);

            if (!_initialized) {
              return Scaffold(
                backgroundColor: const Color.fromARGB(255, 123, 123, 123),
                appBar: AppBar(backgroundColor: const Color.fromARGB(255, 98, 80, 63)),
                body: const Center(child: CircularProgressIndicator(color: Colors.white)),
              );
            }

            final String valueToUse = _statusOptions.contains(_currentStatus)
                ? _currentStatus!
                : 'conferencia';

            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: const Color.fromARGB(255, 123, 123, 123),
              appBar: AppBar(
                title: const Text('EDITAR PROJETO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                backgroundColor: const Color.fromARGB(255, 98, 80, 63),
              ),
              bottomNavigationBar: SizedBox(
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _saveAllChanges,
                  child: const Text('SALVAR ALTERAÇÕES', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              body: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 140,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 98, 80, 63),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Image.asset('assets/imagens/logo/logo ld.png', fit: BoxFit.contain),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- SECTION: CLIENT (Shown for context) ---
                              _sectionCard(
                                title: "CLIENTE",
                                icon: Icons.person,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: _buildTextField(_clientNameController, 'NOME DO CLIENTE')),
                                      const SizedBox(width: 15),
                                      Expanded(child: _buildTextField(_clientPhoneController, 'TELEFONE', formatters: [_phoneFormatter])),
                                    ],
                                  ),
                                ],
                              ),

                              // --- SECTION: ENDEREÇO DA OBRA ---
                              _sectionCard(
                                title: "ENDEREÇO DA OBRA",
                                icon: Icons.location_on,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          _cepController,
                                          'CEP',
                                          formatters: [_cepFormatter],
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) {
                                            if (value.length == 9) {
                                              _buscarEnderecoPorCep(value);
                                            }
                                          },
                                          suffixIcon: _isSearchingCep
                                              ? const Padding(
                                                  padding: EdgeInsets.all(12),
                                                  child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  ),
                                                )
                                              : IconButton(
                                                  icon: const Icon(Icons.search),
                                                  onPressed: () => _buscarEnderecoPorCep(_cepController.text),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  _buildTextField(_addressController, 'ENDEREÇO (RUA, BAIRRO, CIDADE/UF)'),
                                  _buildTextField(
                                    _numberController,
                                    'NÚMERO',
                                    focusNode: _numberFocusNode,
                                  ),
                                ],
                              ),

                              // --- SECTION: PROJECT DETAILS ---
                              _sectionCard(
                                title: "DETALHES DO PROJETO",
                                icon: Icons.assignment,
                                children: [
                                  _buildTextField(_projectNameController, 'NOME DO PROJETO / AMBIENTE'),
                                  _buildTextField(_formaPagamentoController, 'FORMA DE PAGAMENTO'),

                                  _buildTextField(_notesController, 'OBSERVAÇÕES', maxLines: 2),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 60,
                                          margin: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                          child: _buildDateTile('Entrega', _deliveryDate, (d) => setState(() => _deliveryDate = d)),
                                        ),
                                      ),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: valueToUse,
                                          decoration: const InputDecoration(
                                            labelText: 'STATUS DO PROJETO',
                                            labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: 'conferencia', child: Text('Conferência')),
                                            DropdownMenuItem(value: 'pedido', child: Text('Pedido')),
                                            DropdownMenuItem(value: 'producao', child: Text('Produção')),
                                            DropdownMenuItem(value: 'entrega', child: Text('Entrega')),
                                            DropdownMenuItem(value: 'montagem', child: Text('Montagem')),
                                            DropdownMenuItem(value: 'finalizado', child: Text('Finalizado')),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) setState(() => _currentStatus = value);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // --- SECTION: ESPECIFICAÇÕES TÉCNICAS (vindas do orçamento) ---
                              _sectionCard(
                                title: "ESPECIFICAÇÕES TÉCNICAS",
                                icon: Icons.build,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: _buildTextField(_corCaixaController, 'COR DA CAIXARIA')),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: _buildTextField(
                                          _valorCaixaController,
                                          'VALOR CAIXARIA (R\$)',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (_) => _atualizarValorTotal(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(child: _buildTextField(_corAcabController, 'COR DO ACABAMENTO')),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: _buildTextField(
                                          _valorAcabController,
                                          'VALOR ACABAMENTO (R\$)',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (_) => _atualizarValorTotal(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // --- SECTION: EXTRAS (lista dinâmica) ---
                              _sectionCard(
                                title: "EXTRAS / ADICIONAIS",
                                icon: Icons.playlist_add,
                                children: [
                                  if (_extras.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        "Nenhum extra adicionado.",
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                                      ),
                                    ),
                                  ...List.generate(_extras.length, (index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: _buildTextField(_extras[index]['nome']!, 'DESCRIÇÃO DO EXTRA'),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            flex: 2,
                                            child: _buildTextField(
                                              _extras[index]['valor']!,
                                              'VALOR (R\$)',
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              onChanged: (_) => _atualizarValorTotal(),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                                            onPressed: () => _removerExtra(index),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                                      onPressed: _adicionarExtra,
                                      icon: const Icon(Icons.add_circle_outline),
                                      label: const Text("Adicionar Extra"),
                                    ),
                                  ),
                                ],
                              ),

                              // --- SECTION: VALOR TOTAL ---
                              _sectionCard(
                                title: "VALOR DO PROJETO",
                                icon: Icons.attach_money,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          _valorController,
                                          'VALOR TOTAL DO PROJETO',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        tooltip: 'Recalcular a partir da caixaria, acabamento e extras',
                                        icon: const Icon(Icons.calculate, color: Colors.white),
                                        onPressed: _atualizarValorTotal,
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // --- SECTION: FILES, ORÇAMENTOS, CONTRATOS & GALLERY ---
                              _sectionCard(
                                title: "ARQUIVOS DO PROJETO",
                                icon: Icons.folder,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // --- ORÇAMENTOS (PDF) ---
                                      Expanded(child: ExpansionTile(
                                        initiallyExpanded: true,
                                        iconColor: Colors.red,
                                        textColor: Colors.white,
                                        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                        title: const Text("Orçamentos (PDF)", style: TextStyle(fontWeight: FontWeight.bold)),
                                        children: [
                                          _buildFileGrid(pData, 'files', Colors.red),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(foregroundColor: Colors.white),
                                            icon: const Icon(Icons.add),
                                            label: const Text("Adicionar Orçamento(s)"),
                                            onPressed: _isLoading ? null : () => _uploadAndAddFiles('pdf', 'files'),
                                          ),
                                        ],
                                      )),

                                      const SizedBox(width: 20),

                                      // --- CONTRATOS (PDF) ---
                                      Expanded(child: ExpansionTile(
                                        initiallyExpanded: true,
                                        iconColor: const Color(0xFFD4AF37),
                                        textColor: Colors.white,
                                        leading: const Icon(Icons.gavel, color: Color(0xFFD4AF37)),
                                        title: const Text("Contratos (PDF)", style: TextStyle(fontWeight: FontWeight.bold)),
                                        children: [
                                          _buildFileGrid(pData, 'contratos', const Color(0xFFD4AF37)),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(foregroundColor: Colors.white),
                                            icon: const Icon(Icons.add),
                                            label: const Text("Adicionar Contrato(s)"),
                                            onPressed: _isLoading ? null : () => _uploadAndAddFiles('pdf', 'contratos'),
                                          ),
                                        ],
                                      )),

                                      const SizedBox(width: 20),

                                      // --- GALERIA DE FOTOS ---
                                      Expanded(child: ExpansionTile(
                                        initiallyExpanded: true,
                                        iconColor: Colors.blue,
                                        textColor: Colors.white,
                                        leading: const Icon(Icons.image, color: Colors.blue),
                                        title: const Text("Galeria de Fotos", style: TextStyle(fontWeight: FontWeight.bold)),
                                        children: [
                                          _buildFileGrid(pData, 'galleryUrls', Colors.blue),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(foregroundColor: Colors.white),
                                            icon: const Icon(Icons.add),
                                            label: const Text("Adicionar Foto(s)"),
                                            onPressed: _isLoading ? null : () => _uploadAndAddFiles('image', 'galleryUrls'),
                                          ),
                                        ],
                                      )),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Helper Widgets ---

  /// Card estilizado que agrupa uma seção do formulário com título e ícone.
  Widget _sectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    List<TextInputFormatter>? formatters,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    FocusNode? focusNode,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        inputFormatters: formatters,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }


  Widget _buildDateTile(String label, DateTime? dateValue, Function(DateTime) onDateSelected) {
    String formattedDate = dateValue != null
        ? "${dateValue.day.toString().padLeft(2, '0')}/${dateValue.month.toString().padLeft(2, '0')}/${dateValue.year}"
        : 'Selecionar';

    return ListTile(
      dense: true,
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formattedDate, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          const Icon(Icons.calendar_today, size: 16, color: Color.fromARGB(255, 98, 80, 63)),
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

  /// GridView genérico usado para 'files' (orçamentos), 'contratos' e 'galleryUrls'.
  Widget _buildFileGrid(Map<String, dynamic> pData, String fieldName, Color color) {
    final List<dynamic>? items = pData[fieldName] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      return Container(height: 50, alignment: Alignment.center, child: const Text("Nenhum arquivo", style: TextStyle(color: Colors.white54, fontSize: 12)));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 2.5,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final dynamic f = items[i];
        final String name = (f is Map) ? (f['name']?.toString() ?? 'Arquivo') : 'Foto';

        return Material(
          color: Colors.transparent,
          child: ListTile(
            dense: true,
            tileColor: Colors.white.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(4),
            ),
            title: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white)),
            trailing: IconButton(
              icon: Icon(Icons.delete, size: 14, color: color),
              onPressed: _isLoading ? null : () => _deleteFile(fieldName, f),
            ),
          ),
        );
      },
    );
  }
}
