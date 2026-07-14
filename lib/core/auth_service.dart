import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Registro Completo: Auth + Firestore
  Future<User?> register(
    String email, 
    String password, 
    Map<String, dynamic> userData
  ) async {
    try {
      // 1. Cria o usuário no Firebase Authentication
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // 2. Salva os dados extras na coleção 'users' usando o UID do Auth
      // Isso cria uma relação 1:1 entre o login e o perfil do funcionário/admin
      await _db.collection('users').doc(result.user!.uid).set({
        ...userData,
        'email': email.trim().toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'admin', // Você pode definir cargos aqui
      });

      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Erro no Auth: ${e.message}");
      return null;
    } catch (e) {
      debugPrint("Erro geral: $e");
      return null;
    }
  }

  // Login com e-mail e senha
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(), 
        password: password.trim()
      );
      return result.user;
    } catch (e) {
      debugPrint("Erro no login: $e");
      return null;
    }
  }

  // Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Verificar se usuário está logado
  User? get currentUser => _auth.currentUser;
}