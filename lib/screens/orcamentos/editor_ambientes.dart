import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditorAmbienteScreen extends StatefulWidget {
  final String orcamentoId;
  final Map<String, dynamic> projeto;

  const EditorAmbienteScreen({
    super.key,
    required this.orcamentoId,
    required this.projeto,
  });

  @override
  State<EditorAmbienteScreen> createState() => _EditorAmbienteScreenState();
}

class _EditorAmbienteScreenState extends State<EditorAmbienteScreen> {
  // Controladores direto na raiz (sem listas de ambientes)
  final TextEditingController _ctrlNome = TextEditingController();
  final TextEditingController _ctrlCorCaixa = TextEditingController();
  final TextEditingController _ctrlValCaixa = TextEditingController();
  final TextEditingController _ctrlCorAcab = TextEditingController();
  final TextEditingController _ctrlValAcab = TextEditingController();
  List<Map<String, TextEditingController>> _componentes = [];

  Map<String, dynamic> _dadosCliente = {};
  Uint8List? _logoBytes;
  Timer? _debounce;
  bool _isLoading = true;
  final ValueNotifier<int> _pdfTrigger = ValueNotifier(0);
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    try {
      final db = FirebaseFirestore.instance;

      // 1. Busca Cliente
      final docOrcamento = await db.collection('orcamentos').doc(widget.orcamentoId).get();
      if (docOrcamento.exists) {
        _dadosCliente = docOrcamento.data() as Map<String, dynamic>;
      }

      // 2. Busca Projeto (O Ambiente em si)
      String projetoId = widget.projeto['id'] ?? widget.projeto['uid'] ?? '';
      
      if (projetoId.isNotEmpty) {
        final docProjeto = await db
            .collection('orcamentos')
            .doc(widget.orcamentoId)
            .collection('projects')
            .doc(projetoId)
            .get();

        if (docProjeto.exists) {
          final data = docProjeto.data() as Map<String, dynamic>;
          
          setState(() {
            _ctrlNome.text = data['nome']?.toString() ?? widget.projeto['nome'] ?? 'Novo Ambiente';
            _ctrlCorCaixa.text = data['corCaixa']?.toString() ?? '';
            _ctrlValCaixa.text = data['valorCaixa']?.toString() ?? '0.0';
            _ctrlCorAcab.text = data['corAcab']?.toString() ?? '';
            _ctrlValAcab.text = data['valorAcab']?.toString() ?? '0.0';
            
            // Lê da lista 'extras' (ou 'componentes') que está na raiz
            List extrasSalvos = data['extras'] ?? data['componentes'] ?? [];
            _componentes = extrasSalvos.map((c) {
              return {
                'nome': TextEditingController(text: c['nome']?.toString() ?? ''),
                'valor': TextEditingController(text: c['valor']?.toString() ?? '0.0'),
              };
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Erro ao carregar: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _carregarLogo();
    }
  }

  Future<void> _salvarTudo() async {
    setState(() => _isLoading = true);
    try {
      String projetoId = widget.projeto['id'] ?? widget.projeto['uid'] ?? '';
      if (projetoId.isEmpty) throw Exception("ID do projeto não encontrado.");

      final docRef = FirebaseFirestore.instance
          .collection('orcamentos')
          .doc(widget.orcamentoId)
          .collection('projects')
          .doc(projetoId);
      
      double valorCaixa = double.tryParse(_ctrlValCaixa.text.replaceAll(',', '.')) ?? 0.0;
      double valorAcab = double.tryParse(_ctrlValAcab.text.replaceAll(',', '.')) ?? 0.0;
      
      List<Map<String, dynamic>> componentesFormatados = _componentes.map((c) => {
        'nome': c['nome']!.text,
        'valor': double.tryParse(c['valor']!.text.replaceAll(',', '.')) ?? 0.0,
      }).toList();

      // ATUALIZA EXATAMENTE OS CAMPOS EXISTENTES NA RAIZ DO DOCUMENTO
      await docRef.update({
        'nome': _ctrlNome.text,
        'corCaixa': _ctrlCorCaixa.text,
        'valorCaixa': valorCaixa,
        'corAcab': _ctrlCorAcab.text,
        'valorAcab': valorAcab,
        'extras': componentesFormatados, // Mantém o padrão original 'extras'
        'valorTotal': _calcularTotal(),
        'ultimaAtualizacao': FieldValue.serverTimestamp(),
        'itens': FieldValue.delete(), // <-- ISSO APAGA A CAGADA DO ARRAY "ITENS" QUE CRIEI ANTES
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ambiente atualizado com sucesso!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      debugPrint("Erro: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _ctrlNome.dispose();
    _ctrlCorCaixa.dispose();
    _ctrlValCaixa.dispose();
    _ctrlCorAcab.dispose();
    _ctrlValAcab.dispose();
    for (var comp in _componentes) {
      comp['nome']?.dispose();
      comp['valor']?.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _carregarLogo() async {
    try {
      final imageLogo = await rootBundle.load('assets/imagens/logo/logo ld.png');
      setState(() => _logoBytes = imageLogo.buffer.asUint8List());
    } catch (e) {
      debugPrint("Logo não encontrada: $e");
    }
  }

  void _onFieldChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _pdfTrigger.value++; 
    });
  }

  void _adicionarComponente() {
    setState(() {
      _componentes.add({
        'nome': TextEditingController(),
        'valor': TextEditingController(text: "0.00"),
      });
    });
  }

  void _removerComponente(int index) {
    setState(() {
      _componentes[index]['nome']?.dispose();
      _componentes[index]['valor']?.dispose();
      _componentes.removeAt(index);
    });
    _onFieldChanged();
  }

  double _calcularTotal() {
    double vCaixa = double.tryParse(_ctrlValCaixa.text.replaceAll(',', '.')) ?? 0.0;
    double vAcab = double.tryParse(_ctrlValAcab.text.replaceAll(',', '.')) ?? 0.0;
    double vComp = 0.0;
    for (var comp in _componentes) {
      vComp += double.tryParse(comp['valor']!.text.replaceAll(',', '.')) ?? 0.0;
    }
    return vCaixa + vAcab + vComp;
  }

  Future<Uint8List> _buildPdf() async {
    final pdf = pw.Document();
    final corPadrao = PdfColor.fromHex("#012738");
    
    String nomeCliente = _dadosCliente['name']?.toString().toUpperCase() ?? "CLIENTE NÃO INFORMADO";
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          
          String desc = "Caixaria: ${_ctrlCorCaixa.text} (R\$ ${_ctrlValCaixa.text})\n";
          desc += "Acabamentos: ${_ctrlCorAcab.text} (R\$ ${_ctrlValAcab.text})";
          
          for (var comp in _componentes) {
            desc += "\n${comp['nome']!.text}: R\$ ${comp['valor']!.text}";
          }

         return pw.Column(
              children: [
                pw.Container(height: 50, color: corPadrao),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("ORÇAMENTO", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                        pw.Text("Data: ${DateTime.now().toString().substring(0, 10)}"),
                        pw.Text("DELLALIO PLANEJADOS"),
                        pw.Text("(18) 99644-6013"),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("CLIENTE:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(nomeCliente),
                      ],
                    ),
                    if (_logoBytes != null)
                      pw.Image(pw.MemoryImage(_logoBytes!), width: 80),
                  ],
                ),
              
              pw.SizedBox(height: 30),
              pw.Table.fromTextArray(
                headers: ['SERVIÇO', 'DESCRIÇÃO', 'VALOR'],
                data: [
                  [
                    _ctrlNome.text,
                    desc,
                    _currencyFormat.format(_calcularTotal()),
                  ]
                ],
                border: pw.TableBorder.all(),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey700),
                cellAlignment: pw.Alignment.topLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(6), 
                  2: const pw.FlexColumnWidth(2),
                },
              ),
              pw.Spacer(),
              pw.Text("CUSTO TOTAL: ${_currencyFormat.format(_calcularTotal())}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 20),
              pw.Text("FORMA DE PAGAMENTO: a combinar."),
              pw.SizedBox(height: 20),
              pw.Container(height: 30, color: corPadrao),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Editar Ambiente"), backgroundColor: const Color(0xFF012738), foregroundColor: Colors.white),
      body: Row(
        children: [
          // LADO ESQUERDO: Formulário Simples
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _ctrlNome,
                        decoration: const InputDecoration(labelText: "Nome do Ambiente"),
                        onChanged: (_) => _onFieldChanged(),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrlCorCaixa,
                            decoration: const InputDecoration(labelText: "Cor Caixaria"),
                            onChanged: (_) => _onFieldChanged(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _ctrlValCaixa,
                            decoration: const InputDecoration(labelText: "Valor Caixaria"),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            onChanged: (_) => _onFieldChanged(),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrlCorAcab,
                            decoration: const InputDecoration(labelText: "Cor Acabamento"),
                            onChanged: (_) => _onFieldChanged(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _ctrlValAcab,
                            decoration: const InputDecoration(labelText: "Valor Acabamento"),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            onChanged: (_) => _onFieldChanged(),
                          ),
                        ),
                      ]),
                      
                      const Divider(height: 40),
                      const Text("COMPONENTES EXTRAS:", style: TextStyle(fontWeight: FontWeight.bold)),
                      
                      ...List.generate(_componentes.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _componentes[index]['nome'],
                                decoration: const InputDecoration(labelText: "Descrição"),
                                onChanged: (_) => _onFieldChanged(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _componentes[index]['valor'],
                                decoration: const InputDecoration(labelText: "Valor"),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                onChanged: (_) => _onFieldChanged(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removerComponente(index),
                            ),
                          ]),
                        );
                      }),
                      
                      const SizedBox(height: 20),
                      TextButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text("Adicionar Componente"),
                        onPressed: _adicionarComponente,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // LADO DIREITO: PDF e Botão Salvar
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  color: Colors.grey[300],
                  child: Column(
                    children: [
                      Expanded(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _pdfTrigger,
                          builder: (context, value, child) {
                            return PdfPreview(
                              key: ValueKey(value),
                              build: (format) => _buildPdf(),
                              canChangePageFormat: false,
                              canChangeOrientation: false,
                              allowPrinting: true,
                              allowSharing: false,
                              canDebug: false,
                              useActions: false,
                              initialPageFormat: PdfPageFormat.a4,
                              pdfPreviewPageDecoration: const BoxDecoration(
                                color: Colors.white,
                                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
                              ),
                              maxPageWidth: constraints.maxWidth * 0.9,
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16)
                          ),
                          onPressed: _salvarTudo, 
                          child: const Text('SALVAR TUDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                        ),
                      )
                    ],
                  )
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}