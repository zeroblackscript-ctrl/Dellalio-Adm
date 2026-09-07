import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';

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
            style: TextStyle(color: panelIvory, fontSize: 13.5),
            decoration: _dialogDecoration(label, prefixText: "R\$ "),
            onChanged: (value) {
              // Regra: mantemos apenas números.
              // Se o usuário digitar, atualizamos a tela para o cálculo do total
              setDialogState(() {});
            },
          );
        }

        return AlertDialog(
          backgroundColor: inkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text("Configurar: $ambiente",
              style: TextStyle(color: panelIvory, fontWeight: FontWeight.w600, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(children: [
              TextFormField(
                controller: dados['cor caixa'],
                style: TextStyle(color: panelIvory, fontSize: 13.5),
                decoration: _dialogDecoration("Cor da caixaria"),
              ),
              const SizedBox(height: 10),
              buildMoneyField(dados['val caixa'], "Valor caixaria"),
              const SizedBox(height: 10),
              TextFormField(
                controller: dados['cor acab'],
                style: TextStyle(color: panelIvory, fontSize: 13.5),
                decoration: _dialogDecoration("Cor dos acabamentos"),
              ),
              const Divider(),

              Text("Extras:",
                  style: TextStyle(color: panelSlate, fontWeight: FontWeight.w600)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_circle, color: dellalioGold),
                title: Text("Adicionar extra",
                    style: TextStyle(color: panelIvory, fontSize: 14)),
                onTap: () => setDialogState(() {
                  (dados['extras'] as List).add({
                    'desc': TextEditingController(),
                    'val': TextEditingController(text: "R\$ 0,00")
                  });
                }),
              ),
              ...(dados['extras'] as List).map((extra) => Row(children: [
                Expanded(child: TextFormField(
                    controller: extra['desc'],
                    style: TextStyle(color: panelIvory, fontSize: 13.5),
                    decoration: _dialogDecoration("Descrição"))),
                const SizedBox(width: 5),
                Expanded(child: buildMoneyField(extra['val'], "Valor")),
              ])),
              const Divider(),
              Text("Total: R\$ ${_calcularTotalAmbiente(ambiente).toStringAsFixed(2)}",
                  style: TextStyle(color: panelIvory, fontWeight: FontWeight.bold, fontSize: 18)),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Fechar", style: TextStyle(color: panelSlate))),
          ],
        );
      }),
    ).then((_) => setState(() {}));
  }

  InputDecoration _dialogDecoration(String label, {String? prefixText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: panelSlate, fontSize: 13),
      prefixText: prefixText,
      prefixStyle: TextStyle(color: panelSlate),
      filled: true,
      fillColor: inkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: hairlineNavy, width: 1.4),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: hairline),
      ),
    );
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
      backgroundColor: inkPageBg,
      body: Column(
        children: [
          const DellalioSubHeader(title: "Novo projeto"),
          Expanded(
            child: Row(children: [
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(key: _formKey, child: Column(children: [
                DellalioFormField(controller: _nameController, label: "Nome", icon: Icons.person_outline),
                const SizedBox(height: 14),
                DellalioFormField(controller: _phoneController, label: "Telefone", icon: Icons.phone_outlined),
                const SizedBox(height: 14),
                DellalioFormField(controller: _addressController, label: "Endereço", icon: Icons.home_outlined),
                const SizedBox(height: 14),
                DellalioFormField(controller: _notesController, label: "Observações", icon: Icons.notes_outlined),
              ])))),
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _ambientes.map((a) => FilterChip(
                    label: Text(a, style: TextStyle(color: _selecionados[a]! ? inkPageBg : panelSlate, fontSize: 12.5)),
                    selected: _selecionados[a]!,
                    selectedColor: dellalioGold,
                    backgroundColor: inkSurface,
                    checkmarkColor: inkPageBg,
                    side: BorderSide(color: _selecionados[a]! ? dellalioGold : hairline),
                    onSelected: (v) {
                      if (v) {
                        _garantirDadosDoAmbiente(a); // Garante a criação ANTES de atualizar a tela
                      }
                      setState(() => _selecionados[a] = v);
                      if (v) _configurarAmbiente(a);
                    }
                  )).toList()),
                const Divider(),
                Text("Total geral: R\$ ${_totalGeral.toStringAsFixed(2)}",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: panelIvory)),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator(color: dellalioGold))
                else
                  DellalioGoldButton(
                    label: "Salvar orçamento",
                    icon: Icons.save_outlined,
                    fullWidth: true,
                    onPressed: _saveAll,
                  ),
              ]))),
            ]),
          ),
        ],
      ),
    );
  }
}
