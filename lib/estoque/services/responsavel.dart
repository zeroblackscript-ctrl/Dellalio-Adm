import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Quem fez a movimentação: usuário logado, ou "Sistema" na automação.
class Responsavel {
  final String id;
  final String nome;
  const Responsavel(this.id, this.nome);

  static const sistema = Responsavel('sistema', 'Sistema');

  static Responsavel? _cache;

  /// Testes e prévia das telas (sem Firebase Auth).
  static Responsavel? fixoParaTeste;

  /// Usuário logado, com o nome do perfil (`users` dos admins ou
  /// `funcionarios` da equipe). Cai no e-mail se não houver perfil.
  static Future<Responsavel> atual({FirebaseFirestore? db}) async {
    if (fixoParaTeste != null) return fixoParaTeste!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return sistema;
    final cache = _cache;
    if (cache != null && cache.id == user.uid) return cache;
    final fs = db ?? FirebaseFirestore.instance;
    var nome = user.displayName ?? user.email ?? 'Usuário';
    try {
      for (final col in const ['users', 'funcionarios']) {
        final doc = await fs.collection(col).doc(user.uid).get();
        final d = doc.data();
        if (d != null && (d['nome'] ?? '').toString().trim().isNotEmpty) {
          nome = '${d['nome']} ${d['sobrenome'] ?? ''}'.trim();
          break;
        }
      }
    } catch (_) {
      // Sem perfil legível: segue com o e-mail.
    }
    return _cache = Responsavel(user.uid, nome);
  }

  /// Só o primeiro nome ("Marcos"), pra saudação.
  String get primeiroNome => nome.split(' ').first;

  static void limparCache() => _cache = null;
}
