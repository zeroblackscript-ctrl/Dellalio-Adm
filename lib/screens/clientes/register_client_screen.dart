import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

        setState(() {
          _addressController.text =
              "${data['logradouro']}, ${data['bairro']}, ${data['localidade']} - ${data['uf']}";
        });
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

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('clients').add({
        'name': _nameController.text.trim(),
        // Obtém apenas os números, removendo a máscara visual
        'phone': _phoneFormatter.getUnmaskedText(),
        'email': _emailController.text.trim(),
        // Obtém apenas os números do CPF/CNPJ
        'document': _cpfCnpjMasker.getUnmaskedText(),
        'cep': _cepFormatter.getUnmaskedText(),
        'addressNumber': _numberController.text.trim(),
        'address':
            "${_addressController.text.trim()}, nº ${_numberController.text.trim()}",
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
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
      appBar: AppBar(title: const Text('NOVO CLIENTE')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'NOME DO CLIENTE',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _phoneController,
                    inputFormatters: [_phoneFormatter],
                    decoration: const InputDecoration(
                      labelText: 'TELEFONE',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-MAIL',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _documentController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_cpfCnpjMasker],
                    onChanged: (value) {
                      // Remove tudo que não é número para contar os dígitos
                      final cleanValue = value.replaceAll(RegExp(r'\D'), '');

                      // Altera a máscara se passar de 11 dígitos (CNPJ)
                      final newMask = cleanValue.length > 11
                          ? '##.###.###/####-##'
                          : '###.###.###-##';

                      if (_cpfCnpjMasker.getMask() != newMask) {
                        setState(() {
                          _cpfCnpjMasker.updateMask(mask: newMask);
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'CPF ou CNPJ',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _cepController,
                          inputFormatters: [_cepFormatter],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'CEP',
                            border: const OutlineInputBorder(),
                            suffixIcon: _isSearchingCep
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: () =>
                                        _fetchAddressByCep(_cepController.text),
                                  ),
                          ),
                          onChanged: (v) {
                            if (v.length == 9) _fetchAddressByCep(v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _numberController,
                          decoration: const InputDecoration(
                            labelText: 'Nº',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'ENDEREÇO (Completo)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.home),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'OBSERVAÇÕES',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _saveClient,
                            child: const Text('SALVAR CLIENTE'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
