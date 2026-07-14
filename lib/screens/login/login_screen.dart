
import 'package:DELLALIO/core/auth_service.dart';
import 'package:DELLALIO/core/user_session.dart';
import 'package:DELLALIO/screens/login/registro_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../inicio/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
final TextEditingController _passwordController = TextEditingController();
final TextEditingController _adminKeyController = TextEditingController();
final AuthService _authService = AuthService();
bool _isLoading = false;

// Método de login atualizado
void _login() async {
  setState(() => _isLoading = true);

  // 1. Se o campo de código de administrador foi preenchido, validamos
  // ANTES de autenticar. Se estiver incorreto, bloqueamos totalmente o
  // login (nem como funcionário comum) e avisamos o usuário.
  final String enteredAdminKey = _adminKeyController.text.trim();
  if (enteredAdminKey.isNotEmpty &&
      enteredAdminKey.toLowerCase() != UserSession.adminKey.toLowerCase()) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código de administrador incorreto. Login bloqueado.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final user = await _authService.login(_emailController.text, _passwordController.text);
  
  if (user != null) {
    // Valida (opcionalmente) o código de Administrador. Se estiver correto,
    // essa sessão passa a ter privilégios totais; caso contrário (campo
    // vazio), o login segue normalmente como um funcionário comum.
    await UserSession.validateAndSetAdmin(enteredAdminKey);

    if (!mounted) return;

    // Log/feedback de sucesso do login, indicando se entrou como Admin.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          UserSession.isAdmin()
              ? 'Login efetuado como ADMINISTRADOR.'
              : 'Login efetuado com sucesso.',
        ),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => DashboardScreen())
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Credenciais inválidas.'), backgroundColor: Colors.red)
    );
  }
  
  setState(() => _isLoading = false);
}


// Envia e-mail de redefinição de senha via Firebase Auth
void _forgotPassword() async {
  final email = _emailController.text.trim();
  if (email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Digite seu e-mail no campo acima para recuperar a senha.'), backgroundColor: Colors.orange),
    );
    return;
  }

  setState(() => _isLoading = true);
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('E-mail de redefinição enviado para $email. Verifique sua caixa de entrada.'), backgroundColor: Colors.green),
    );
  } on FirebaseAuthException catch (e) {
    String msg;
    switch (e.code) {
      case 'user-not-found':
        msg = 'Nenhuma conta encontrada com este e-mail.';
        break;
      case 'invalid-email':
        msg = 'E-mail inválido.';
        break;
      default:
        msg = 'Erro ao enviar e-mail: ${e.message}';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro inesperado: $e'), backgroundColor: Colors.red));
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'DELLALIO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  letterSpacing: 10,
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.w300,
                ),
              ),
              const Text(
                'CÉREBRO • CONTROL',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 4,
                  color: Colors.white38,
                ),
              ),
              // Dentro do Column do seu Build:
TextField(
  controller: _emailController,
  decoration: const InputDecoration(labelText: 'E-MAIL', prefixIcon: Icon(Icons.email)),
),
const SizedBox(height: 16),
TextField(
  controller: _passwordController,
  onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _login();
                      }
                    },
  obscureText: true,
  decoration: const InputDecoration(labelText: 'SENHA', prefixIcon: Icon(Icons.lock)),
),
const SizedBox(height: 16),
TextField(
  controller: _adminKeyController,
  obscureText: true,
  onSubmitted: (value) => _login(),
  decoration: const InputDecoration(
    labelText: 'CÓDIGO DE ADMINISTRADOR (opcional)',
    prefixIcon: Icon(Icons.admin_panel_settings),
  ),
),
const SizedBox(height: 24),
_isLoading 
  ? const CircularProgressIndicator() 
  : ElevatedButton(onPressed: _login, child: const Text('ENTRAR'),style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: _isLoading ? null : _forgotPassword,
                  child: const Text(
                    'ESQUECI MINHA SENHA',
                    style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
               ElevatedButton(onPressed:() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }, child: const Text('REGISTRAR'),style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),),
             
            ],
          ),
        ),
      ),
    );
  }
}
