import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'fonte_notas.dart';

/// Fotos de DANFE tiradas no Gerenciador (`notas_fotos`, status
/// `pendente`). Cada foto é reivindicada numa transação — com dois Cérebros
/// abertos, só um processa — e entregue como [ArquivoNota].
class FonteFotosCelular implements FonteNotas {
  FonteFotosCelular({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  final StreamController<ArquivoNota> _saida = StreamController.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  /// id do documento da foto → pra marcar o resultado depois.
  final Map<String, DocumentReference<Map<String, dynamic>>> _docs = {};

  @override
  Stream<ArquivoNota> get arquivos => _saida.stream;

  @override
  Future<void> iniciar() async {
    await _sub?.cancel();
    _sub = _db
        .collection('notas_fotos')
        .where('status', isEqualTo: 'pendente')
        .snapshots()
        .listen((s) {
          for (final d in s.docs) {
            _reivindicar(d.reference);
          }
        }, onError: (_) {});
  }

  Future<void> _reivindicar(DocumentReference<Map<String, dynamic>> ref) async {
    final minha = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (snap.data()?['status'] != 'pendente') return false;
      tx.update(ref, {'status': 'processando'});
      return true;
    }).catchError((_) => false);
    if (!minha) return;
    try {
      final d = (await ref.get()).data()!;
      final resp = await http.get(Uri.parse(d['url'] as String));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final nome = (d['nome'] ?? 'nota.jpg').toString();
      _docs[nome] = ref;
      _saida.add(ArquivoNota(nome: nome, bytes: resp.bodyBytes));
    } catch (e) {
      await ref.update({'status': 'erro', 'erro': '$e'});
    }
  }

  /// Resultado da importação, pra quem fotografou ver no histórico.
  Future<void> concluir(String nome, {String? notaId, Object? erro}) async {
    final ref = _docs.remove(nome);
    if (ref == null) return;
    await ref.update({
      'status': erro != null ? 'erro' : (notaId == null ? 'repetida' : 'lida'),
      'notaId': ?notaId,
      if (erro != null) 'erro': '$erro',
    });
  }

  bool ehDela(String nome) => _docs.containsKey(nome);

  @override
  Future<void> parar() async {
    await _sub?.cancel();
    _sub = null;
  }
}
