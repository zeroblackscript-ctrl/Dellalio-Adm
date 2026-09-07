import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';

class EditClientScreen extends StatefulWidget {
  final String clientId;
  const EditClientScreen({super.key, required this.clientId});

  @override
  State<EditClientScreen> createState() => _EditClientScreenState();
}

class _EditClientScreenState extends State<EditClientScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _documentController = TextEditingController();
  final _cepController = TextEditingController();
  final _numberController = TextEditingController();
  final _numberFocusNode = FocusNode();

  final _phoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final _cpfCnpjFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final _cepFormatter = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _initialized = false;
  bool _isLoading = false;
  bool _isSearchingCep = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _documentController.dispose();
    _cepController.dispose();
    _numberController.dispose();
    _numberFocusNode.dispose();
    super.dispose();
  }

  void _initializeData(Map<String, dynamic>? cData) {
    if (_initialized) return;
    _initialized = true;

    final data = cData ?? {};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameController.text = data['name'] ?? '';
      _emailController.text = data['email'] ?? '';
      _phoneController.text = _phoneFormatter.maskText(data['phone'] ?? '');
      _documentController.text = _cpfCnpjFormatter.maskText(data['document'] ?? '');
      _notesController.text = data['notes'] ?? '';
      _cepController.text = _cepFormatter.maskText(data['cep'] ?? '');
      _numberController.text = data['addressNumber']?.toString() ?? '';
      _addressController.text = data['address'] ?? '';
      setState(() {});
    });
  }

  Future<void> _buscarEnderecoPorCep(String cep) async {
    final cleanCep = cep.replaceAll(RegExp(r'\D'), '');
    if (cleanCep.length != 8) return;
    setState(() => _isSearchingCep = true);
    try {
      final response = await http.get(Uri.parse('https://viacep.com.br/ws/$cleanCep/json/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('erro')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CEP NÃO ENCONTRADO')));
          return;
        }
        if (!mounted) return;
        setState(() {
          _addressController.text = "${data['logradouro']}, ${data['bairro']} - ${data['localidade']}/${data['uf']}";
        });
        FocusScope.of(context).requestFocus(_numberFocusNode);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ERRO AO BUSCAR CEP')));
    } finally {
      if (mounted) setState(() => _isSearchingCep = false);
    }
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      String phoneRaw = _phoneFormatter.getUnmaskedText();
      if (phoneRaw.isEmpty) phoneRaw = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      String docRaw = _cpfCnpjFormatter.getUnmaskedText();
      if (docRaw.isEmpty) docRaw = _documentController.text.replaceAll(RegExp(r'\D'), '');
      String cepRaw = _cepFormatter.getUnmaskedText();
      if (cepRaw.isEmpty) cepRaw = _cepController.text.replaceAll(RegExp(r'\D'), '');
      final String numero = _numberController.text.trim();
      final String enderecoBase = _addressController.text.trim();
      final String enderecoCompleto = enderecoBase.isEmpty ? '' : (numero.isEmpty ? enderecoBase : "$enderecoBase, N° $numero");

      await FirebaseFirestore.instance.collection('clients').doc(widget.clientId).update({
        'name': _nameController.text.trim(),
        'phone': phoneRaw,
        'email': _emailController.text.trim(),
        'document': docRaw,
        'cep': cepRaw,
        'addressNumber': numero,
        'address': enderecoCompleto,
        'notes': _notesController.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CLIENTE ATUALIZADO COM SUCESSO!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ERRO AO SALVAR: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('clients').doc(widget.clientId).snapshots(),
      builder: (context, cSnap) {
        if (!cSnap.hasData) {
          return _buildScaffoldShell(
            child: const Center(child: CircularProgressIndicator(color: dellalioGold)),
          );
        }
        if (!cSnap.data!.exists) {
          return _buildScaffoldShell(
            child: Center(child: Text('Cliente não encontrado.\nEle pode ter sido excluído.', textAlign: TextAlign.center, style: TextStyle(color: panelSlate, fontSize: 16))),
          );
        }

        final cData = cSnap.data!.data() as Map<String, dynamic>?;
        _initializeData(cData);

        if (!_initialized) {
          return _buildScaffoldShell(
            child: const Center(child: CircularProgressIndicator(color: dellalioGold)),
          );
        }

        return Scaffold(
          backgroundColor: inkPageBg,
          body: Column(
            children: [
              const DellalioSubHeader(title: "Editar cliente"),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Dados do cliente",
                                  style: TextStyle(color: dellalioLabel, fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 10),
                              DellalioFormField(
                                controller: _nameController,
                                label: "Nome do cliente",
                                icon: Icons.person_outline,
                                validator: (v) => (v == null || v.isEmpty) ? "Campo obrigatório" : null,
                              ),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: DellalioFormField(
                                  controller: _phoneController,
                                  label: "Telefone",
                                  icon: Icons.phone_outlined,
                                  inputFormatters: [_phoneFormatter],
                                )),
                                const SizedBox(width: 15),
                                Expanded(child: DellalioFormField(
                                  controller: _documentController,
                                  label: "CPF / CNPJ",
                                  icon: Icons.badge_outlined,
                                  inputFormatters: [_cpfCnpjFormatter],
                                )),
                              ]),
                              const SizedBox(height: 12),
                              DellalioFormField(
                                controller: _emailController,
                                label: "E-mail",
                                icon: Icons.email_outlined,
                              ),
                              const SizedBox(height: 20),
                              Text("Endereço",
                                  style: TextStyle(color: dellalioLabel, fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 10),
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(child: DellalioFormField(
                                  controller: _cepController,
                                  label: "CEP",
                                  icon: Icons.location_on_outlined,
                                  inputFormatters: [_cepFormatter],
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) { if (value.length == 9) _buscarEnderecoPorCep(value); },
                                  suffixIcon: _isSearchingCep
                                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                                      : IconButton(icon: const Icon(Icons.search), onPressed: () => _buscarEnderecoPorCep(_cepController.text)),
                                )),
                              ]),
                              const SizedBox(height: 12),
                              DellalioFormField(
                                controller: _addressController,
                                label: "Endereço (rua, bairro, cidade/UF)",
                                icon: Icons.home_outlined,
                              ),
                              const SizedBox(height: 12),
                              DellalioFormField(
                                controller: _numberController,
                                label: "Número",
                                icon: Icons.pin_outlined,
                                focusNode: _numberFocusNode,
                              ),
                              const SizedBox(height: 20),
                              Text("Observações",
                                  style: TextStyle(color: dellalioLabel, fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 10),
                              DellalioFormField(
                                controller: _notesController,
                                label: "Observações",
                                icon: Icons.notes_outlined,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    label: "Salvar alterações",
                    icon: Icons.save_outlined,
                    fullWidth: true,
                    onPressed: _saveClient,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildScaffoldShell({required Widget child}) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: Column(
        children: [
          const DellalioSubHeader(title: "Editar cliente"),
          Expanded(child: child),
        ],
      ),
    );
  }
}
