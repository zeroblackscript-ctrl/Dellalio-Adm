import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigurarAmbienteScreen extends StatefulWidget {
  final String orcamentoId;

  const ConfigurarAmbienteScreen({super.key, required this.orcamentoId});

  @override
  State<ConfigurarAmbienteScreen> createState() => _ConfigurarAmbienteScreenState();
}

class _ConfigurarAmbienteScreenState extends State<ConfigurarAmbienteScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();

  final Map<String, Map<String, dynamic>> _dadosAmbientes = {};
  final List<String> _ambientes = ['SALA', 'COZINHA', 'QUARTO', 'HALL', 'COPA', 'LAVANDERIA', 'AREA GOURMET'];
  final Map<String, bool> _selecionados = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    for (var a in _ambientes) {
      _selecionados[a] = false;
    }
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('orcamentos').doc(widget.orcamentoId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _addressController.text = data['address'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar dados: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _parseCurrency(String val) {
    String clean = val.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }

  // MÉTODO CRUCIAL: Garante que TODAS as chaves existam antes de qualquer leitura
  void _garantirDadosDoAmbiente(String ambiente) {
    if (!_dadosAmbientes.containsKey(ambiente)) {
      _dadosAmbientes[ambiente] = {
        'cor caixa': TextEditingController(),
        'val caixa': TextEditingController(text: "R\$ 0,00"),
        'cor acab': TextEditingController(),
        'extras': <Map<String, TextEditingController>>[],
      };
    }
  }

  void _configurarAmbiente(String ambiente) {
    _garantirDadosDoAmbiente(ambiente);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        final Map<String, dynamic> dados = _dadosAmbientes[ambiente]!;

        Widget buildMoneyField(TextEditingController controller, String label) {
          return TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              prefixText: "R\$ ",
            ),
            onChanged: (value) {
              // Regra: mantemos apenas números.
              // Se o usuário digitar, atualizamos a tela para o cálculo do total
              setDialogState(() {});
            },
          );
        }

        return AlertDialog(
          title: Text("Configurar: $ambiente"),
          content: SingleChildScrollView(
            child: Column(children: [
              TextFormField(
                controller: dados['cor caixa'],
                decoration: const InputDecoration(labelText: "Cor da Caixaria", border: OutlineInputBorder())
              ),
              const SizedBox(height: 10),
              buildMoneyField(dados['val caixa'], "Valor Caixaria"),
              const SizedBox(height: 10),
              TextFormField(
                controller: dados['cor acab'],
                decoration: const InputDecoration(labelText: "Cor dos Acabamentos", border: OutlineInputBorder())
              ),
              const Divider(),

              const Text("EXTRAS:"),
              ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.green),
                title: const Text("Adicionar Extra"),
                onTap: () => setDialogState(() {
                  (dados['extras'] as List).add({
                    'desc': TextEditingController(),
                    'val': TextEditingController(text: "R\$ 0,00")
                  });
                }),
              ),
              ...(dados['extras'] as List).map((extra) => Row(children: [
                Expanded(child: TextFormField(controller: extra['desc'], decoration: const InputDecoration(labelText: "Descrição"))),
                const SizedBox(width: 5),
                Expanded(child: buildMoneyField(extra['val'], "Valor")),
              ])),
              const Divider(),
              Text("TOTAL: R\$ ${_calcularTotalAmbiente(ambiente).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fechar"))],
        );
      }),
    ).then((_) => setState(() {}));
  }

  double _calcularTotalAmbiente(String ambiente) {
    if (!_dadosAmbientes.containsKey(ambiente)) return 0.0;
    var d = _dadosAmbientes[ambiente]!;

    // Leitura 100% segura usando operadores de nulidade para evitar crash
    double total = _parseCurrency((d['val caixa'] as TextEditingController?)?.text ?? "0,00");

    for (var extra in (d['extras'] as List)) {
      total += _parseCurrency((extra['val'] as TextEditingController?)?.text ?? "0,00");
    }
    return total;
  }

  double get _totalGeral {
    double total = 0;
    for (var a in _ambientes) {
      if (_selecionados[a] == true) {
        total += _calcularTotalAmbiente(a);
      }
    }
    return total;
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Atualiza os dados do cliente no documento pai (caso tenham sido editados)
      await FirebaseFirestore.instance.collection('orcamentos').doc(widget.orcamentoId).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
      });

      // Salva cada ambiente selecionado na subcoleção 'projects' do ID fornecido
      for (var a in _ambientes) {
        if (_selecionados[a] == true) {
          var d = _dadosAmbientes[a]!;
          var ambienteData = {
            'nome': a,
            'valorTotal': _calcularTotalAmbiente(a),
            'corCaixa': (d['cor caixa'] as TextEditingController).text,
            'valorCaixa': _parseCurrency((d['val caixa'] as TextEditingController).text),
            'corAcab': (d['cor acab'] as TextEditingController).text,
            'extras': (d['extras'] as List).map((ex) => {
              'desc': (ex['desc'] as TextEditingController).text,
              'valor': _parseCurrency((ex['val'] as TextEditingController).text)
            }).toList(),
            'createdAt': FieldValue.serverTimestamp(),
          };
          await FirebaseFirestore.instance.collection('orcamentos').doc(widget.orcamentoId).collection('projects').add(ambienteData);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("NOVO PROJETO")),
      body: Row(children: [
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(key: _formKey, child: Column(children: [
          TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Nome")),
          TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: "Telefone")),
          TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: "Endereço")),
          TextFormField(controller: _notesController, decoration: const InputDecoration(labelText: "Observações")),
        ])))),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
          Wrap(children: _ambientes.map((a) => FilterChip(
            label: Text(a),
            selected: _selecionados[a]!,
            onSelected: (v) {
              if (v) {
                _garantirDadosDoAmbiente(a); // Garante a criação ANTES de atualizar a tela
              }
              setState(() => _selecionados[a] = v);
              if (v) _configurarAmbiente(a);
            }
          )).toList()),
          const Divider(),
          Text("TOTAL GERAL: R\$ ${_totalGeral.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ElevatedButton(onPressed: _isLoading ? null : _saveAll, child: const Text("SALVAR ORÇAMENTO")),
        ]))),
      ]),
    );
  }
}
