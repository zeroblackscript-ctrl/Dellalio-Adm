import 'package:cloud_firestore/cloud_firestore.dart';

import '../importacao/conversor_unidades.dart';
import '../models/models.dart';
import '../util/normalizar.dart';
import 'estoque_service.dart';

/// Cadastro (dados que não são saldo): materiais, fornecedores e
/// configurações. Saldo continua só pelo [EstoqueService].
class CadastroService {
  CadastroService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  static final CadastroService instancia = CadastroService();

  static const _camposDeSaldo = {'estoqueFisico', 'estoqueReservado', 'custoMedio'};

  /// Material novo manual. Saldo inicial entra como `ajuste` "Saldo inicial".
  Future<String> criarMaterial(MaterialEstoque m, {double saldoInicial = 0, double? custo}) async {
    final ref = _db.collection('materiais').doc();
    await ref.set({
      ...m.copyWith(
        estoqueFisico: 0,
        estoqueReservado: 0,
        apelidos: {...m.apelidos, normalizar(m.nome)}.toList(),
      ).toMap(),
      'criadoEm': FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
    if (saldoInicial > 0) {
      await EstoqueService(db: _db).entrada(
        materialId: ref.id,
        quantidade: saldoInicial,
        custoUnitario: custo,
        motivo: 'Saldo inicial',
      );
    }
    return ref.id;
  }

  /// "Editar dados". Nunca mexe em saldo (regra 1).
  Future<void> atualizarMaterial(String id, Map<String, Object?> campos) async {
    final limpos = Map.of(campos)..removeWhere((k, _) => _camposDeSaldo.contains(k));
    if (limpos['nome'] is String) {
      limpos['apelidos'] = FieldValue.arrayUnion([normalizar(limpos['nome']! as String)]);
    }
    await _db.collection('materiais').doc(id).update({
      ...limpos,
      // Completar dados tira o selo "novo".
      'criadoAutomaticamente': false,
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }

  Future<void> definirAtivo(String id, bool ativo) => _db
      .collection('materiais')
      .doc(id)
      .update({'ativo': ativo, 'atualizadoEm': FieldValue.serverTimestamp()});

  Future<String> salvarFornecedor(Fornecedor f) async {
    final col = _db.collection('fornecedores');
    if (f.id.isEmpty) return (await col.add(f.toMap())).id;
    await col.doc(f.id).set(f.toMap(), SetOptions(merge: true));
    return f.id;
  }

  // ---------------------------------------------------- configuração

  DocumentReference<Map<String, dynamic>> get _config =>
      _db.collection('config').doc('estoque');

  /// Carrega a chapa padrão (compartilhada entre as máquinas).
  Future<void> carregarConfig() async {
    try {
      final d = (await _config.get()).data();
      final larg = d?['chapaPadraoLarguraMm'];
      final alt = d?['chapaPadraoAlturaMm'];
      if (larg is num && larg > 0) ChapaPadrao.larguraMm = larg.toDouble();
      if (alt is num && alt > 0) ChapaPadrao.alturaMm = alt.toDouble();
    } catch (_) {
      // Fica o padrão 2750 × 1850.
    }
  }

  Future<void> salvarChapaPadrao(double larguraMm, double alturaMm) async {
    ChapaPadrao.larguraMm = larguraMm;
    ChapaPadrao.alturaMm = alturaMm;
    await _config.set({
      'chapaPadraoLarguraMm': larguraMm,
      'chapaPadraoAlturaMm': alturaMm,
    }, SetOptions(merge: true));
  }
}
