import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';

class RegisterClientScreen extends StatefulWidget {
  const RegisterClientScreen({super.key});

  @override
  State<RegisterClientScreen> createState() => _RegisterClientScreenState();
}

class _RegisterClientScreenState extends State<RegisterClientScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cepController = TextEditingController();
  final _numberController = TextEditingController(); // Número da casa
  final _documentController = TextEditingController();
  final _numberFocusNode = FocusNode();

  final _cepFormatter = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {"#": RegExp(r'[0-9]')},
  );
  final _phoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );
  final _cpfCnpjMasker = MaskTextInputFormatter(
    mask: '###.###.###-##', // Começa como CPF
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _isSearchingCep = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cepController.dispose();
    _numberController.dispose();
    _documentController.dispose();
    _numberFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchAddressByCep(String cep) async {
    final cleanCep = cep.replaceAll(RegExp(r'\D'), '');
    if (cleanCep.length != 8) return;

    setState(() => _isSearchingCep = true);
    try {
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$cleanCep/json/'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('erro')) throw Exception('CEP não encontrado');

        if (!mounted) return;
        setState(() {
          _addressController.text =
              "${data['logradouro']}, ${data['bairro']}, ${data['localidade']} - ${data['uf']}";
        });
        FocusScope.of(context).requestFocus(_numberFocusNode);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erro ao buscar CEP')));
    } finally {
      if (mounted) setState(() => _isSearchingCep = false);
    }
  }

  // --- Salvar Cliente ---
  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha os campos obrigatórios!')),
      );
      return;
    }
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final String numero = _numberController.text.trim();
      final String enderecoBase = _addressController.text.trim();
      final String enderecoCompleto = enderecoBase.isEmpty
          ? ''
          : (numero.isEmpty ? enderecoBase : "$enderecoBase, nº $numero");

      await FirebaseFirestore.instance.collection('clients').add({
        'name': _nameController.text.trim(),
        'phone': _phoneFormatter.getUnmaskedText(),
        'email': _emailController.text.trim(),
        'document': _cpfCnpjMasker.getUnmaskedText(),
        'cep': _cepFormatter.getUnmaskedText(),
        'addressNumber': numero,
        'address': enderecoCompleto,
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente cadastrado com sucesso!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: Column(
        children: [
          const DellalioSubHeader(title: "Novo cliente"),
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
                              style: TextStyle(
                                  color: dellalioLabel,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          const SizedBox(height: 10),
                          DellalioFormField(
                            controller: _nameController,
                            label: "Nome do cliente",
                            icon: Icons.person_outline,
                            validator: (v) => (v == null || v.isEmpty)
                                ? "Campo obrigatório"
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                                child: DellalioFormField(
                              controller: _phoneController,
                              label: "Telefone",
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [_phoneFormatter],
                            )),
                            const SizedBox(width: 15),
                            Expanded(
                                child: DellalioFormField(
                              controller: _documentController,
                              label: "CPF / CNPJ",
                              icon: Icons.badge_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [_cpfCnpjMasker],
                              onChanged: (value) {
                                final cleanValue =
                                    value.replaceAll(RegExp(r'\D'), '');
                                final newMask = cleanValue.length > 11
                                    ? '##.###.###/####-##'
                                    : '###.###.###-##';
                                if (_cpfCnpjMasker.getMask() != newMask) {
                                  setState(() {
                                    _cpfCnpjMasker.updateMask(mask: newMask);
                                  });
                                }
                              },
                            )),
                          ]),
                          const SizedBox(height: 12),
                          DellalioFormField(
                            controller: _emailController,
                            label: "E-mail",
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),
                          Text("Endereço",
                              style: TextStyle(
                                  color: dellalioLabel,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              flex: 2,
                              child: DellalioFormField(
                                controller: _cepController,
                                label: "CEP",
                                icon: Icons.location_on_outlined,
                                keyboardType: TextInputType.number,
                                inputFormatters: [_cepFormatter],
                                onChanged: (v) {
                                  if (v.length == 9) _fetchAddressByCep(v);
                                },
                                suffixIcon: _isSearchingCep
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2)))
                                    : IconButton(
                                        icon: const Icon(Icons.search),
                                        onPressed: () => _fetchAddressByCep(
                                            _cepController.text),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              flex: 1,
                              child: DellalioFormField(
                                controller: _numberController,
                                label: "Nº",
                                icon: Icons.pin_outlined,
                                keyboardType: TextInputType.number,
                                focusNode: _numberFocusNode,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          DellalioFormField(
                            controller: _addressController,
                            label: "Endereço (rua, bairro, cidade/UF)",
                            icon: Icons.home_outlined,
                          ),
                          const SizedBox(height: 20),
                          Text("Observações",
                              style: TextStyle(
                                  color: dellalioLabel,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
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
                label: "Salvar cliente",
                icon: Icons.save_outlined,
                fullWidth: true,
                onPressed: _saveClient,
              ),
      ),
    );
  }
}
