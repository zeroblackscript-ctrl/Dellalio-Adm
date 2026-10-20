import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Consultas ao vivo usadas pelas telas. As automações mudam os dados
/// sozinhas, então tudo aqui é `snapshots()`.
class Consultas {
  Consultas({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  /// Trocável nos testes/prévia (Firestore falso).
  static Consultas instancia = Consultas();

  Stream<List<MaterialEstoque>> materiais({bool incluirInativos = false}) =>
      _db.collection('materiais').snapshots().map((s) {
        final lista = s.docs.map(MaterialEstoque.fromFirestore).where(
          (m) => incluirInativos || m.ativo,
        ).toList()
          ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        return lista;
      });

  Stream<MaterialEstoque?> material(String id) => _db
      .collection('materiais')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? MaterialEstoque.fromFirestore(d) : null);

  /// Listas que ainda seguram reserva, em ordem de chegada.
  Stream<List<ListaCorte>> listasAtivas() => _db
      .collection('listas_corte')
      .where('status', whereIn: [
        StatusLista.lida.name,
        StatusLista.reservada.name,
        StatusLista.aguardandoCompra.name,
        StatusLista.pronta.name,
      ])
      .snapshots()
      .map((s) => s.docs.map(ListaCorte.fromFirestore).toList()
        ..sort(_porChegada));

  Stream<List<ListaCorte>> listasRecentes({int limite = 50}) => _db
      .collection('listas_corte')
      .orderBy('criadoEm', descending: true)
      .limit(limite)
      .snapshots()
      .map((s) => s.docs.map(ListaCorte.fromFirestore).toList());

  Stream<ListaCorte?> lista(String id) => _db
      .collection('listas_corte')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? ListaCorte.fromFirestore(d) : null);

  Stream<List<Movimentacao>> movimentacoesRecentes({int limite = 10}) => _db
      .collection('movimentacoes')
      .orderBy('criadoEm', descending: true)
      .limit(limite)
      .snapshots()
      .map((s) => s.docs.map(Movimentacao.fromFirestore).toList());

  Stream<List<Movimentacao>> movimentacoesDoMaterial(
    String materialId, {
    int limite = 20,
  }) => _db
      .collection('movimentacoes')
      .where('materialId', isEqualTo: materialId)
      .orderBy('criadoEm', descending: true)
      .limit(limite)
      .snapshots()
      .map((s) => s.docs.map(Movimentacao.fromFirestore).toList());

  Stream<List<PedidoCompra>> pedidos(StatusPedido status) => _db
      .collection('pedidos_compra')
      .where('status', isEqualTo: status.name)
      .snapshots()
      .map((s) => s.docs.map(PedidoCompra.fromFirestore).toList()
        ..sort((a, b) {
          // "Sem fornecedor" por último.
          if (a.semFornecedor != b.semFornecedor) return a.semFornecedor ? 1 : -1;
          return a.fornecedorNome.compareTo(b.fornecedorNome);
        }));

  Stream<List<Fornecedor>> fornecedores() => _db
      .collection('fornecedores')
      .snapshots()
      .map((s) => s.docs.map(Fornecedor.fromFirestore).toList()
        ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase())));

  /// Notas com item esperando confirmação (embalagem, "É X?").
  Stream<List<NotaFiscal>> notasPendentes() => _db
      .collection('notas_fiscais')
      .where('status', isEqualTo: StatusNota.parcial.name)
      .snapshots()
      .map((s) => s.docs
          .map(NotaFiscal.fromFirestore)
          .where((n) => n.itens.any((i) => i.situacao == SituacaoItemNota.confirmar))
          .toList());

  Stream<NotaFiscal?> nota(String id) => _db
      .collection('notas_fiscais')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? NotaFiscal.fromFirestore(d) : null);

  /// Movimentações a partir de [desde] (mais novas primeiro).
  Stream<List<Movimentacao>> movimentacoesDesde(DateTime desde, {int limite = 2000}) => _db
      .collection('movimentacoes')
      .where('criadoEm', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
      .orderBy('criadoEm', descending: true)
      .limit(limite)
      .snapshots()
      .map((s) => s.docs.map(Movimentacao.fromFirestore).toList());

  Stream<int> avisosNaoLidos() => _db
      .collection('avisos')
      .where('lido', isEqualTo: false)
      .snapshots()
      .map((s) => s.size);

  static int _porChegada(ListaCorte a, ListaCorte b) {
    final da = a.criadoEm, dbb = b.criadoEm;
    if (da == null && dbb == null) return a.id.compareTo(b.id);
    if (da == null) return 1; // ainda sem timestamp do servidor: acabou de chegar
    if (dbb == null) return -1;
    return da.compareTo(dbb);
  }

  static int porChegada(ListaCorte a, ListaCorte b) => _porChegada(a, b);
}
