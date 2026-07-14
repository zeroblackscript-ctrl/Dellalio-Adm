import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class VisualizarPdfScreen extends StatefulWidget {
  final String orcamentoId;
  final List<dynamic> ambientesSelecionados; // Lista de objetos (cada um é um ambiente)
  final Map<String, dynamic> dadosCliente;

  const VisualizarPdfScreen({
    super.key,
    required this.orcamentoId,
    required this.ambientesSelecionados,
    required this.dadosCliente,
  });

  @override
  State<VisualizarPdfScreen> createState() => _VisualizarPdfScreenState();
}

class _VisualizarPdfScreenState extends State<VisualizarPdfScreen> {
  Uint8List? _logoBytes;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
Map<String, dynamic>? _clienteCompleto;

  @override
  void initState() {
    super.initState();
    _buscarDadosDoCliente();
    _carregarLogo();
  }

  Future<void> _buscarDadosDoCliente() async {
  final doc = await FirebaseFirestore.instance
      .collection('orcamentos')
      .doc(widget.orcamentoId) // Certifique-se de passar esse ID no construtor
      .get();
  
  if (doc.exists) {
    setState(() {
      _clienteCompleto = doc.data();
    });
  }
}

  Future<void> _carregarLogo() async {
    try {
      final imageLogo = await rootBundle.load('assets/imagens/logo/logo ld.png');
      if (mounted) {
        setState(() => _logoBytes = imageLogo.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint("Erro ao carregar logo: $e");
    }
  }

  // Calcula o total somando o valorTotal de cada item da lista
  double _calcularTotalGeral() {
    double total = 0.0;
    for (var p in widget.ambientesSelecionados) {
      total += (p['valorTotal'] ?? 0.0).toDouble();
    }
    return total;
  }

  Future<Uint8List> _buildPdf() async {
    final pdf = pw.Document();
    final corPadrao = PdfColor.fromHex("#012738");
    String nomeCliente = widget.dadosCliente['name']?.toString().toUpperCase() ?? "CLIENTE NÃO INFORMADO";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
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
                     pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.end,
  children: [
    pw.Text("CLIENTE:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    pw.Text((_clienteCompleto?['name'] ?? "").toUpperCase()),
    pw.Text("Tel: ${_clienteCompleto?['phone'] ?? 'N/A'}"),
    pw.Text("End: ${_clienteCompleto?['address'] ?? 'N/A'}"),
  ],
),
                    ],
                  ),
                  if (_logoBytes != null) pw.Image(pw.MemoryImage(_logoBytes!), width: 80),
                ],
              ),
              pw.SizedBox(height: 30),
              
              // Tabela iterando sobre todos os ambientes selecionados
              pw.Table.fromTextArray(
                headers: ['SERVIÇO', 'DESCRIÇÃO', 'VALOR'],
                data: widget.ambientesSelecionados.map((p) {
                  // Monta a descrição lendo os campos diretamente do objeto 'p'
                  String desc = "Caixaria: ${p['corCaixa'] ?? ''} (R\$ ${p['valorCaixa'] ?? 0})\n";
                  desc += "Acabamentos: ${p['corAcab'] ?? ''} ";
                  
                  // Lê o campo 'extras' (ou 'componentes') da raiz do documento
                  var extras = p['extras'] ?? p['componentes'] ?? [];
                  for (var comp in extras) {
                    desc += "\n${comp['nome'] ?? ''}: R\$ ${comp['valor'] ?? 0}";
                  }

                  return [
                    p['nome'] ?? 'Sem nome',
                    desc,
                    _currencyFormat.format(p['valorTotal'] ?? 0.0),
                  ];
                }).toList(),
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
              pw.Text("CUSTO TOTAL: ${_currencyFormat.format(_calcularTotalGeral())}",
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Visualizar Orçamento"),
        backgroundColor: const Color(0xFF012738),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
                return  ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: PdfPreview(
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
                             
            ),
          );}
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Gera o PDF e abre o menu de impressão/compartilhamento do sistema
          final pdfBytes = await _buildPdf();
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfBytes,
            name: "Orcamento_${widget.dadosCliente['name'] ?? 'cliente'}",
          );
        },
        backgroundColor: const Color(0xFF012738),
        icon: const Icon(Icons.print, color: Colors.white),
        label: const Text("Imprimir", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}