import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  final _emailController = TextEditingController();
  final _nomeController = TextEditingController();
  final _sobrenomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _passController = TextEditingController();
  final _oldPassController = TextEditingController();

  bool _isLoading = false;
  bool _isUploading = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _emailController.text = _user.email ?? '';
        _nomeController.text = data['nome'] ?? '';
        _sobrenomeController.text = data['sobrenome'] ?? '';
        _telefoneController.text = data['telefone'] ?? '';
        _enderecoController.text = data['endereco'] ?? '';
        _photoUrl = _user.photoURL;
      }
    } catch (e) {
      debugPrint("Erro ao carregar dados: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final ref = FirebaseStorage.instance.ref().child('user_photos').child('${_user!.uid}.jpg');
      await ref.putFile(File(image.path));
      final downloadUrl = await ref.getDownloadURL();
      await _user.updatePhotoURL(downloadUrl);
      setState(() => _photoUrl = downloadUrl);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto atualizada!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
  Future<void> _updateProfile() async {
    // Validação da troca de senha ANTES de qualquer alteração
    final bool wantsPasswordChange =
        _passController.text.isNotEmpty || _oldPassController.text.isNotEmpty;

    if (wantsPasswordChange) {
      if (_oldPassController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Informe sua senha atual para alterar a senha."), backgroundColor: Colors.orange),
        );
        return;
      }
      if (_passController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Informe a nova senha."), backgroundColor: Colors.orange),
        );
        return;
      }
      if (_passController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("A nova senha deve ter pelo menos 6 caracteres."), backgroundColor: Colors.orange),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      // Auth Update - Senha (feito primeiro, pois requer reautenticação)
      if (wantsPasswordChange) {
        try {
          final cred = EmailAuthProvider.credential(email: _user!.email!, password: _oldPassController.text);
          await _user.reauthenticateWithCredential(cred);
          await _user.updatePassword(_passController.text);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Senha alterada com sucesso!"), backgroundColor: Colors.green),
            );
          }
          _passController.clear();
          _oldPassController.clear();
        } on FirebaseAuthException catch (e) {
          String msg;
          switch (e.code) {
            case 'wrong-password':
            case 'invalid-credential':
              msg = 'Senha atual incorreta.';
              break;
            case 'weak-password':
              msg = 'A nova senha é muito fraca.';
              break;
            case 'requires-recent-login':
              msg = 'Sessão expirada. Faça login novamente para trocar a senha.';
              break;
            default:
              msg = 'Erro ao alterar senha: ${e.message}';
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
          }
          setState(() => _isLoading = false);
          return; // Não prossegue para os demais updates se a senha falhar
        }
      }

      // Auth Update - E-mail
      if (_emailController.text != _user!.email) {
        await _user.verifyBeforeUpdateEmail(_emailController.text);
      }

      // Firestore Update
      await FirebaseFirestore.instance.collection('users').doc(_user.uid).update({
        'fotoUrl': _photoUrl,
        'nome': _nomeController.text,
        'sobrenome': _sobrenomeController.text,
        'telefone': _telefoneController.text,
        'endereco': _enderecoController.text,
        'email': _emailController.text,
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Perfil atualizado!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  void dispose() {
    _emailController.dispose();
    _nomeController.dispose();
    _sobrenomeController.dispose();
    _telefoneController.dispose();
    _enderecoController.dispose();
    _passController.dispose();
    _oldPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: Column(
        children: [
          const DellalioSubHeader(title: "Meu perfil"),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: dellalioGold))
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _isUploading ? null : _pickAndUploadImage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: inkSurfaceHover,
                                child: _photoUrl != null
                                  ? ClipRRect(borderRadius: BorderRadius.circular(60), child: CachedNetworkImage(imageUrl: _photoUrl!, fit: BoxFit.cover, width: 120, height: 120, cacheKey: _photoUrl))
                                  : Icon(Icons.person, size: 60, color: panelSlate),
                              ),
                              if (_isUploading) const CircularProgressIndicator(color: dellalioGold),
                              if (!_isUploading) const Positioned(bottom: 0, right: 0, child: Icon(Icons.camera_alt, color: dellalioGold, size: 30)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DellalioFormField(controller: _nomeController, label: "Nome", icon: Icons.person_outline),
                      const SizedBox(height: 14),
                      DellalioFormField(controller: _sobrenomeController, label: "Sobrenome"),
                      const SizedBox(height: 14),
                      DellalioFormField(controller: _emailController, label: "E-mail", icon: Icons.email_outlined),
                      const SizedBox(height: 14),
                      DellalioFormField(controller: _telefoneController, label: "Celular", icon: Icons.phone_outlined),
                      const SizedBox(height: 14),
                      DellalioFormField(controller: _enderecoController, label: "Endereço", icon: Icons.home_outlined),
                      const Divider(height: 40),
                      DellalioFormField(controller: _oldPassController, label: "Senha atual (para alterar senha)", icon: Icons.lock_outline, obscure: true),
                      const SizedBox(height: 14),
                      DellalioFormField(controller: _passController, label: "Nova senha", icon: Icons.lock_reset_outlined, obscure: true),
                      const SizedBox(height: 30),
                      DellalioGoldButton(
                        label: "Salvar alterações",
                        icon: Icons.save_outlined,
                        fullWidth: true,
                        onPressed: _updateProfile,
                      )
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
