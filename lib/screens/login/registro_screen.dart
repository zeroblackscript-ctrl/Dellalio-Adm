import 'package:DELLALIO/core/auth_service.dart';
import 'package:flutter/material.dart';
import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _nomeController = TextEditingController();
  final _sobrenomeController = TextEditingController();
  final _telefoneController = TextEditingController();

  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _nomeController.dispose();
    _sobrenomeController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final data = {
      'nome': _nomeController.text.trim(),
      'sobrenome': _sobrenomeController.text.trim(),
      'telefone': _telefoneController.text.trim(),
    };

    final user = await _authService.register(
      _emailController.text,
      _passController.text,
      data,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Administrador criado com sucesso!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro ao criar usuário. Verifique os dados."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: Column(
        children: [
          const DellalioSubHeader(title: "Novo acesso"),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Dados do administrador",
                              style: TextStyle(
                                  color: dellalioLabel,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                                child: DellalioFormField(
                              controller: _nomeController,
                              label: "Nome",
                              icon: Icons.person_outline,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? "Campo obrigatório"
                                  : null,
                            )),
                            const SizedBox(width: 15),
                            Expanded(
                                child: DellalioFormField(
                              controller: _sobrenomeController,
                              label: "Sobrenome",
                              icon: Icons.person_outline,
                            )),
                          ]),
                          const SizedBox(height: 12),
                          DellalioFormField(
                            controller: _telefoneController,
                            label: "Telefone",
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 20),
                          Text("Credenciais de acesso",
                              style: TextStyle(
                                  color: dellalioLabel,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          const SizedBox(height: 10),
                          DellalioFormField(
                            controller: _emailController,
                            label: "E-mail",
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v == null || !v.contains('@'))
                                ? "E-mail inválido"
                                : null,
                          ),
                          const SizedBox(height: 12),
                          DellalioFormField(
                            controller: _passController,
                            label: "Senha (mínimo 6 caracteres)",
                            icon: Icons.lock_outline,
                            obscure: true,
                            validator: (v) => (v == null || v.length < 6)
                                ? "Mínimo 6 caracteres"
                                : null,
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
                label: "Cadastrar administrador",
                icon: Icons.person_add_alt_1_outlined,
                fullWidth: true,
                onPressed: _handleRegister,
              ),
      ),
    );
  }
}
