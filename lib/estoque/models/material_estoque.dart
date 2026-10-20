import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'leitura.dart';

/// Documento de `materiais/{id}`.
///
/// Chama-se `MaterialEstoque` (e não `Material`) pra não colidir com o
/// widget `Material` do Flutter em toda tela que importa os dois.
class MaterialEstoque {
  final String id;
  final String nome;
  final CategoriaMaterial categoria;
  final UnidadeEstoque unidade;
  final double? espessuraMm;
  final double? larguraMm;
  final double? alturaMm;
  final String? cor;
  final String? refFornecedor;
  final String? fornecedorId;

  /// Descrições já vistas em listas/notas, normalizadas.
  final List<String> apelidos;
  final double estoqueFisico;
  final double estoqueReservado;
  final double estoqueMinimo;
  final double custoMedio;
  final String? local;
  final bool criadoAutomaticamente;

  /// Ex.: "criado pela lista Cozinha Rodrigues".
  final String? origemCriacao;
  final bool ativo;

  /// Unidades por embalagem comercial aprendidas das notas (`CX` → 100).
  final Map<String, double> fatorEmbalagem;
  final DateTime? atualizadoEm;

  const MaterialEstoque({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.unidade,
    this.espessuraMm,
    this.larguraMm,
    this.alturaMm,
    this.cor,
    this.refFornecedor,
    this.fornecedorId,
    this.apelidos = const [],
    this.estoqueFisico = 0,
    this.estoqueReservado = 0,
    this.estoqueMinimo = 0,
    this.custoMedio = 0,
    this.local,
    this.criadoAutomaticamente = false,
    this.origemCriacao,
    this.ativo = true,
    this.fatorEmbalagem = const {},
    this.atualizadoEm,
  });

  /// Sempre calculado, nunca gravado.
  double get disponivel => estoqueFisico - estoqueReservado;

  bool get abaixoDoMinimo => estoqueMinimo > 0 && disponivel < estoqueMinimo;

  double get valorEmEstoque => estoqueFisico * custoMedio;

  factory MaterialEstoque.fromMap(String id, Map<String, dynamic> d) {
    return MaterialEstoque(
      id: id,
      nome: lerTexto(d['nome']) ?? 'Sem nome',
      categoria: CategoriaMaterial.fromName(d['categoria'] as String?),
      unidade: UnidadeEstoque.fromName(d['unidade'] as String?),
      espessuraMm: lerNumOuNulo(d['espessuraMm']),
      larguraMm: lerNumOuNulo(d['larguraMm']),
      alturaMm: lerNumOuNulo(d['alturaMm']),
      cor: lerTexto(d['cor']),
      refFornecedor: lerTexto(d['refFornecedor']),
      fornecedorId: lerTexto(d['fornecedorId']),
      apelidos: lerListaTexto(d['apelidos']),
      estoqueFisico: lerNum(d['estoqueFisico']),
      estoqueReservado: lerNum(d['estoqueReservado']),
      estoqueMinimo: lerNum(d['estoqueMinimo']),
      custoMedio: lerNum(d['custoMedio']),
      local: lerTexto(d['local']),
      criadoAutomaticamente: d['criadoAutomaticamente'] == true,
      origemCriacao: lerTexto(d['origemCriacao']),
      ativo: d['ativo'] != false,
      fatorEmbalagem: lerMapaNum(d['fatorEmbalagem']),
      atualizadoEm: lerData(d['atualizadoEm']),
    );
  }

  factory MaterialEstoque.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      MaterialEstoque.fromMap(doc.id, doc.data() ?? const {});

  /// Campos de cadastro + saldo. `atualizadoEm` fica a cargo de quem grava.
  Map<String, dynamic> toMap() => semNulos({
    'nome': nome,
    'categoria': categoria.name,
    'unidade': unidade.name,
    'espessuraMm': espessuraMm,
    'larguraMm': larguraMm,
    'alturaMm': alturaMm,
    'cor': cor,
    'refFornecedor': refFornecedor,
    'fornecedorId': fornecedorId,
    'apelidos': apelidos,
    'estoqueFisico': estoqueFisico,
    'estoqueReservado': estoqueReservado,
    'estoqueMinimo': estoqueMinimo,
    'custoMedio': custoMedio,
    'local': local,
    'criadoAutomaticamente': criadoAutomaticamente,
    'origemCriacao': origemCriacao,
    'ativo': ativo,
    'fatorEmbalagem': fatorEmbalagem,
  });

  MaterialEstoque copyWith({
    String? nome,
    CategoriaMaterial? categoria,
    UnidadeEstoque? unidade,
    double? espessuraMm,
    double? larguraMm,
    double? alturaMm,
    String? cor,
    String? refFornecedor,
    String? fornecedorId,
    List<String>? apelidos,
    double? estoqueFisico,
    double? estoqueReservado,
    double? estoqueMinimo,
    double? custoMedio,
    String? local,
    bool? criadoAutomaticamente,
    String? origemCriacao,
    bool? ativo,
    Map<String, double>? fatorEmbalagem,
    DateTime? atualizadoEm,
  }) {
    return MaterialEstoque(
      id: id,
      nome: nome ?? this.nome,
      categoria: categoria ?? this.categoria,
      unidade: unidade ?? this.unidade,
      espessuraMm: espessuraMm ?? this.espessuraMm,
      larguraMm: larguraMm ?? this.larguraMm,
      alturaMm: alturaMm ?? this.alturaMm,
      cor: cor ?? this.cor,
      refFornecedor: refFornecedor ?? this.refFornecedor,
      fornecedorId: fornecedorId ?? this.fornecedorId,
      apelidos: apelidos ?? this.apelidos,
      estoqueFisico: estoqueFisico ?? this.estoqueFisico,
      estoqueReservado: estoqueReservado ?? this.estoqueReservado,
      estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
      custoMedio: custoMedio ?? this.custoMedio,
      local: local ?? this.local,
      criadoAutomaticamente:
          criadoAutomaticamente ?? this.criadoAutomaticamente,
      origemCriacao: origemCriacao ?? this.origemCriacao,
      ativo: ativo ?? this.ativo,
      fatorEmbalagem: fatorEmbalagem ?? this.fatorEmbalagem,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }
}
