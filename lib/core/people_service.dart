import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa uma pessoa do sistema (Administrador ou Funcionário),
/// unificando as coleções `users` (admins) e `funcionarios` (funcionários)
/// para permitir a seleção de destinatários de chat em ambos os apps.
class Person {
  final String uid;
  final String nome;
  final String sobrenome;
  final String fotoUrl;
  final String role;
  final String origem; // 'users' ou 'funcionarios'

  Person({
    required this.uid,
    required this.nome,
    required this.sobrenome,
    required this.fotoUrl,
    required this.role,
    required this.origem,
  });

  String get fullName => "$nome $sobrenome".trim();

  factory Person.fromDoc(DocumentSnapshot doc, String origem) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Person(
      uid: doc.id,
      nome: (data['nome'] ?? '').toString(),
      sobrenome: (data['sobrenome'] ?? '').toString(),
      fotoUrl: (data['fotoUrl'] ?? '').toString(),
      role: (data['role'] ?? '').toString(),
      origem: origem,
    );
  }
}

/// Serviço compartilhado que busca e unifica as pessoas cadastradas
/// nas coleções 'users' (administradores) e 'funcionarios' (equipe),
/// permitindo que qualquer um dos dois apps (cerebro / cerebro_adm)
/// monte listas de seleção de destinatários para o chat.
class PeopleService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Busca todas as pessoas (admins + funcionários), exceto o [excludeUid]
  /// (normalmente o usuário logado), unificadas em uma única lista.
  static Future<List<Person>> fetchAllPeople({String? excludeUid}) async {
    final results = await Future.wait([
      _db.collection('users').get(),
      _db.collection('funcionarios').get(),
    ]);

    final List<Person> people = [];

    for (final doc in results[0].docs) {
      people.add(Person.fromDoc(doc, 'users'));
    }
    for (final doc in results[1].docs) {
      // Evita duplicar caso o mesmo UID exista (por engano) nas duas coleções
      if (!people.any((p) => p.uid == doc.id)) {
        people.add(Person.fromDoc(doc, 'funcionarios'));
      }
    }

    if (excludeUid != null) {
      people.removeWhere((p) => p.uid == excludeUid);
    }

    people.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return people;
  }

  /// Busca os dados (nome, foto) de uma única pessoa pelo UID,
  /// procurando primeiro em 'users' e depois em 'funcionarios'.
  static Future<Person?> fetchPerson(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.exists) return Person.fromDoc(userDoc, 'users');

    final funcDoc = await _db.collection('funcionarios').doc(uid).get();
    if (funcDoc.exists) return Person.fromDoc(funcDoc, 'funcionarios');

    return null;
  }
}
