import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class Editorcamento extends StatefulWidget {
  final String orcamentoId;
  const Editorcamento({super.key, required this.orcamentoId});

  @override
  State<Editorcamento> createState() => _EditorcamentoState();
}

class _EditorcamentoState extends State<Editorcamento> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _documentController = TextEditingController();
  final _projectNameController = TextEditingController();
  final _valorController = TextEditingController();
  String? _clientId;
  final _phoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final _cpfCnpjFormatter = MaskTextInputFormatter(
    mask:
        '###.###.###-##', // Você pode criar lógica para alternar entre CPF/CNPJ se desejar
    filter: {"#": RegExp(r'[0-9]')},
  );
  DateTime? _deliveryDate;
  DateTime? _deliveryCreate;
  bool _isLoading = false;
  bool _initialized = false;

  Future<void> _fetchClientDetails(String clientId) async {
  final doc = await FirebaseFirestore.instance.collection('clients').doc(clientId).get();
  if (doc.exists && mounted) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _nameController.text = data['name'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _addressController.text = data['address'] ?? '';
      _emailController.text = data['email'] ?? '';
      _documentController.text = data['document'] ?? '';
    });
  }
}

  Future<void> _uploadAndAddFile(
    String projectId,
    String type,
    String fieldName,
    bool isList,
  ) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: type == 'pdf' ? FileType.custom : FileType.image,
      allowedExtensions: type == 'pdf' ? ['pdf'] : null,
      withData: true,
    );

    if (result == null || result.files.first.bytes == null) return;

    setState(() => _isLoading = true);
    try {
      final fileName = result.files.first.name;
      final bytes = result.files.first.bytes!;
      final ref = FirebaseStorage.instance.ref().child(
        '${type}s/${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      final updateData = isList
          ? {
              fieldName: FieldValue.arrayUnion([
                type == 'pdf' ? {'name': fileName, 'url': url} : url,
              ]),
            }
          : {fieldName: url};

      await FirebaseFirestore.instance
          .collection('orcamentos')
          .doc(widget.orcamentoId)
          .collection('projects')
          .doc(projectId)
          .update(updateData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao subir: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFile(
    String projectId,
    String fieldName,
    dynamic fileData,
  ) async {
    try {
      final url = fileData is Map ? fileData['url'] : fileData;
      await FirebaseStorage.instance.refFromURL(url).delete();
      await FirebaseFirestore.instance
          .collection('orcamentos')
          .doc(widget.orcamentoId)
          .collection('projects')
          .doc(projectId)
          .update({
            fieldName: FieldValue.arrayRemove([fileData]),
          });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao deletar: $e')));
    }
  }
 

 Future<void> _updateClient(String projectId) async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isLoading = true);
  
  try {
    // Pegue o texto, mas trate o mask formatter
    String phoneRaw = _phoneFormatter.getUnmaskedText();
    // Se o unmask retornar vazio (caso o usuário não tenha mexido), 
    // garanta que pegamos o texto puro ou mantemos o valor atual
      if (phoneRaw.isEmpty) {
        phoneRaw = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      }

    await FirebaseFirestore.instance
        .collection('orcamentos')
        .doc(widget.orcamentoId)
        .update({
          'name': _nameController.text.trim(),
          'phone': phoneRaw, // Envia apenas números
          'email': _emailController.text.trim(),
          'document': _cpfCnpjFormatter.getUnmaskedText().isEmpty 
                      ? _documentController.text.replaceAll(RegExp(r'\D'), '') 
                      : _cpfCnpjFormatter.getUnmaskedText(),
          'address': _addressController.text.trim(),
        });
   
      await FirebaseFirestore.instance
          .collection('orcamentos')
          .doc(widget.orcamentoId)
          .collection('projects')
          .doc(projectId)
          .update({
            'projectName': _projectNameController.text.trim(),
            'valor': _valorController.text.trim(),
            'notes': _notesController.text.trim(),
            'deliveryDate': _deliveryDate,
            'deliveryCreate': _deliveryCreate,
          });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 123, 123, 123),

      appBar: AppBar(
        title: const Text('EDITAR CLIENTE E PROJETO'),
        backgroundColor: const Color.fromARGB(255, 98, 80, 63),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orcamentos')
            .doc(widget.orcamentoId)
            .snapshots(),
        builder: (context, cSnap) {
          if (!cSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orcamentos')
                .doc(widget.orcamentoId)
                .collection('projects')
                .snapshots(),
            builder: (context, pSnap) {
  // 1. Verifique se tem dados e feche o if com chaves { }
  if (!pSnap.hasData || pSnap.data!.docs.isEmpty) {
    return const Center(child: CircularProgressIndicator());
  }
// Dentro do StreamBuilder, onde você processa o pSnap:
// final cData = cSnap.data!.data() as Map<String, dynamic>;
final pDoc = pSnap.data!.docs.first;
final pData = pDoc.data() as Map<String, dynamic>;
// Dentro do builder do cSnap:
final cData = cSnap.data!.data() as Map<String, dynamic>;

// Salve o clientId se existir no orçamento
if (cData.containsKey('clientId') && _clientId == null) {
  _clientId = cData['clientId'];
  _fetchClientDetails(_clientId!); 
}

// O restante do seu código de inicialização:
if (!_initialized) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    // Se não tiver clientId, preenche com o que tem no orçamento (legado)
    if (_clientId == null) {
        _nameController.text = cData['name'] ?? '';
        _emailController.text = cData['email'] ?? '';
        _addressController.text = cData['address'] ?? '';
        _phoneController.text = cData['phone'] ?? '';
        _documentController.text = cData['document'] ?? '';
    }
    
    _projectNameController.text = pData['projectName'] ?? '';
    _notesController.text = pData['notes'] ?? '';
    
    // Corrigindo o erro do Double aqui:
    final valor = pData['valor'];
    final valorText = valor != null ? valor.toString().replaceAll('.', ',') : '0,00';

    setState(() {
      _initialized = true;
      _valorController.text = valorText;
    });
  });
}
           
              return Scaffold(
                bottomNavigationBar: SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      // Remove o arredondamento definindo o BorderRadius como zero
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      // Remove a sombra padrão para ficar mais plano
                      elevation: 0,
                    ),
                    onPressed: () => _updateClient(pDoc.id),
                    child: const Text(
                      'SALVAR ALTERAÇÕES',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                body: ListView(
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 98, 80, 63),
                      ),

                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(
                          'assets/imagens/logo/logo ld.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    Form(
                      key: _formKey,
                      child: GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400,
                              childAspectRatio: 4,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                            ),
                        children: [
                          _buildTextField(_nameController, 'NOME DO CLIENTE'),
                          _buildTextField(
                            _projectNameController,
                            'NOME DO PROJETO',
                          ),
                          _buildTextField(
                            _phoneController,
                            'TELEFONE',
                            formatters: [_phoneFormatter],
                          ),
                          _buildTextField(_emailController, 'E-MAIL'),
                          _buildTextField(
                            _documentController,
                            'CPF / CNPJ',
                            formatters: [_cpfCnpjFormatter],
                          ),
                          _buildTextField(_addressController, 'ENDEREÇO'),
                          _buildTextField(_valorController, 'VALOR'),

                          

                          
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LADO ESQUERDO: PDFs
                        Expanded(
                          child: ExpansionTile(
                            initiallyExpanded:
                                true, // Começa aberto, mas pode fechar
                            leading: const Icon(
                              Icons.picture_as_pdf,
                              color: Colors.red,
                            ),
                            title: const Text("Documentos PDF"),
                            children: [
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(10),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount:
                                          2, // 2 por linha dentro da coluna
                                      childAspectRatio: 3,
                                      crossAxisSpacing: 5,
                                      mainAxisSpacing: 5,
                                    ),
                                itemCount:
                                    (pData['files'] as List?)?.length ?? 0,
                                itemBuilder: (context, i) {
                                  final f = pData['files'][i] as Map;
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      title: Text(
                                        f['name'] ?? 'Arquivo',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _deleteFile(pDoc.id, 'files', f),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text("Adicionar PDF"),
                                onPressed: () => _uploadAndAddFile(
                                  pDoc.id,
                                  'pdf',
                                  'files',
                                  true,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          width: 20,
                        ), // Espaçamento entre as colunas
                        // LADO DIREITO: FOTOS
                        Expanded(
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            leading: const Icon(
                              Icons.image,
                              color: Colors.blue,
                            ),
                            title: const Text("Galeria de Fotos"),
                            children: [
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(10),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3, // Menores, 3 por linha
                                      crossAxisSpacing: 5,
                                      mainAxisSpacing: 5,
                                    ),
                                itemCount:
                                    (pData['galleryUrls'] as List?)?.length ??
                                    0,
                                itemBuilder: (context, i) {
                                  final url = pData['galleryUrls'][i];
                                  return Stack(
                                    children: [
                                      Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        width: 80,
                                        height: 80,
                                      ),
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 16,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black,
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                          onPressed: () => _deleteFile(
                                            pDoc.id,
                                            'galleryUrls',
                                            url,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text("Adicionar Foto"),
                                onPressed: () => _uploadAndAddFile(
                                  pDoc.id,
                                  'image',
                                  'galleryUrls',
                                  true,
                                ),
                              ),
                            ],
                          ),
                        ),
                       
                      ],
                    ),

                    const SizedBox(height: 30),
                    
                    const SizedBox(height: 50),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    List<TextInputFormatter>? formatters,
  }) {
    return TextFormField(
      controller: controller,
      inputFormatters: formatters,
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.black, width: 2.0),
        ),
      ),
    );
  }


}
