import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Tela simples e robusta para editar apenas os dados do CLIENTE
/// (nome, telefone, e-mail, documento, endereço, observações).
///
/// A edição de projetos específicos deve ser feita através da tela
/// [EditProjectScreen], acessada a partir da lista de projetos do cliente.
/// Esta tela NÃO depende da existência de nenhum projeto, corrigindo o bug
/// de loading infinito quando o cliente tinha 0 ou mais de 1 projeto.
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

    // Marca como inicializado IMEDIATAMENTE para evitar loading infinito,
    // mesmo que os dados venham nulos ou incompletos.
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

      // O endereço pode já ter sido salvo com número embutido; tentamos
      // exibir só a parte "base" caso addressNumber exista separadamente.
      _addressController.text = data['address'] ?? '';

      // Força rebuild para exibir os valores preenchidos nos controllers
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

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      String phoneRaw = _phoneFormatter.getUnmaskedText();
      if (phoneRaw.isEmpty) {
        phoneRaw = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      }

      String docRaw = _cpfCnpjFormatter.getUnmaskedText();
      if (docRaw.isEmpty) {
        docRaw = _documentController.text.replaceAll(RegExp(r'\D'), '');
      }

      String cepRaw = _cepFormatter.getUnmaskedText();
      if (cepRaw.isEmpty) {
        cepRaw = _cepController.text.replaceAll(RegExp(r'\D'), '');
      }

      final String numero = _numberController.text.trim();
      final String enderecoBase = _addressController.text.trim();
      final String enderecoCompleto = enderecoBase.isEmpty
          ? ''
          : (numero.isEmpty ? enderecoBase : "$enderecoBase, N° $numero");

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
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
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 123, 123, 123),
            appBar: AppBar(
              title: const Text('EDITAR CLIENTE'),
              backgroundColor: const Color.fromARGB(255, 98, 80, 63),
            ),
            body: const Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (!cSnap.data!.exists) {
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 123, 123, 123),
            appBar: AppBar(
              title: const Text('EDITAR CLIENTE'),
              backgroundColor: const Color.fromARGB(255, 98, 80, 63),
            ),
            body: const Center(
              child: Text(
                'Cliente não encontrado.\nEle pode ter sido excluído.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          );
        }

        final cData = cSnap.data!.data() as Map<String, dynamic>?;
        _initializeData(cData);

        if (!_initialized) {
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 123, 123, 123),
            appBar: AppBar(
              title: const Text('EDITAR CLIENTE'),
              backgroundColor: const Color.fromARGB(255, 98, 80, 63),
            ),
            body: const Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        return Scaffold(
          backgroundColor: const Color.fromARGB(255, 123, 123, 123),
          appBar: AppBar(
            title: const Text('EDITAR CLIENTE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
              onPressed: _isLoading ? null : _saveClient,
              child: _isLoading
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('SALVAR ALTERAÇÕES', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                height: 160,
                decoration: const BoxDecoration(color: Color.fromARGB(255, 98, 80, 63)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Image.asset('assets/imagens/logo/logo ld.png', fit: BoxFit.contain),
                ),
              ),
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
                              const Text("DADOS DO CLIENTE",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 10),
                              _buildTextField(_nameController, 'NOME DO CLIENTE', required: true),
                              Row(
                                children: [
                                  Expanded(child: _buildTextField(_phoneController, 'TELEFONE', formatters: [_phoneFormatter])),
                                  const SizedBox(width: 15),
                                  Expanded(child: _buildTextField(_documentController, 'CPF / CNPJ', formatters: [_cpfCnpjFormatter])),
                                ],
                              ),
                              _buildTextField(_emailController, 'E-MAIL'),

                              const SizedBox(height: 20),
                              const Text("ENDEREÇO",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 10),
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
                                        if (value.length == 9) _buscarEnderecoPorCep(value);
                                      },
                                      suffixIcon: _isSearchingCep
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 16, height: 16,
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
                              _buildTextField(_numberController, 'NÚMERO', focusNode: _numberFocusNode),

                              const SizedBox(height: 20),
                              const Text("OBSERVAÇÕES",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 10),
                              _buildTextField(_notesController, 'OBSERVAÇÕES', maxLines: 3),
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
        );
      },
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
    bool required = false,
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
        validator: required ? (v) => (v == null || v.isEmpty) ? "Campo obrigatório" : null : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
