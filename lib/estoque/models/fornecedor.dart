import 'package:cloud_firestore/cloud_firestore.dart';

import 'leitura.dart';

/// Documento de `fornecedores/{id}`.
class Fornecedor {
  final String id;
  final String nome;
  final String? cnpj;

  /// Formato `55DDDNUMERO`.
  final String? whatsapp;
  final String? email;

  /// Texto curto mostrado no card do pedido ("chapas e fitas").
  final String? descricao;

  /// `cProd` da nota → materialId, aprendido automaticamente.
  final Map<String, String> codigosProduto;

  const Fornecedor({
    required this.id,
    required this.nome,
    this.cnpj,
    this.whatsapp,
    this.email,
    this.descricao,
    this.codigosProduto = const {},
  });

  /// "(18) 99712-4410" a partir de `5518997124410`.
  String? get whatsappFormatado {
    final w = whatsapp;
    if (w == null) return null;
    final d = w.replaceAll(RegExp(r'\D'), '');
    final local = d.startsWith('55') && d.length > 11 ? d.substring(2) : d;
    if (local.length < 10) return w;
    final ddd = local.substring(0, 2);
    final numero = local.substring(2);
    final corte = numero.length - 4;
    return '($ddd) ${numero.substring(0, corte)}-${numero.substring(corte)}';
  }

  factory Fornecedor.fromMap(String id, Map<String, dynamic> d) => Fornecedor(
    id: id,
    nome: lerTexto(d['nome']) ?? 'Fornecedor',
    cnpj: lerTexto(d['cnpj']),
    whatsapp: lerTexto(d['whatsapp']),
    email: lerTexto(d['email']),
    descricao: lerTexto(d['descricao']),
    codigosProduto: lerMapaTexto(d['codigosProduto']),
  );

  factory Fornecedor.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Fornecedor.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => semNulos({
    'nome': nome,
    'cnpj': cnpj,
    'whatsapp': whatsapp,
    'email': email,
    'descricao': descricao,
    'codigosProduto': codigosProduto,
  });

  Fornecedor copyWith({
    String? nome,
    String? cnpj,
    String? whatsapp,
    String? email,
    String? descricao,
    Map<String, String>? codigosProduto,
  }) {
    return Fornecedor(
      id: id,
      nome: nome ?? this.nome,
      cnpj: cnpj ?? this.cnpj,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      descricao: descricao ?? this.descricao,
      codigosProduto: codigosProduto ?? this.codigosProduto,
    );
  }
}
