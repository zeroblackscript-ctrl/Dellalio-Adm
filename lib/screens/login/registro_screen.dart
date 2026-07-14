import 'package:DELLALIO/core/auth_service.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _nomeController = TextEditingController();
  final _sobrenomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  
  final _authService = AuthService();
  bool _isLoading = false;

  void _handleRegister() async {
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha e-mail e senha!")));
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'nome': _nomeController.text.trim(),
      'sobrenome': _sobrenomeController.text.trim(),
      'telefone': _telefoneController.text.trim(),
    };

    final user = await _authService.register(
      _emailController.text, 
      _passController.text, 
      data
    );

    setState(() => _isLoading = false);

    if (user != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Administrador criado com sucesso!"), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao criar usuário. Verifique os dados."), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("NOVO ACESSO")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.all(32.0),
            children: [
              TextField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome')),
              TextField(controller: _sobrenomeController, decoration: const InputDecoration(labelText: 'Sobrenome')),
              TextField(controller: _telefoneController, decoration: const InputDecoration(labelText: 'Telefone')),
              const SizedBox(height: 20),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'E-mail')),
              TextField(controller: _passController, decoration: const InputDecoration(labelText: 'Senha', helperText: 'Mínimo 6 caracteres'), obscureText: true),
              const SizedBox(height: 30),
              _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleRegister, 
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
                    child: const Text("CADASTRAR ADMINISTRADOR")
                  ),
            ],
          ),
        ),
      ),
    );
  }
}