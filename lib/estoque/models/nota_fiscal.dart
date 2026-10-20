import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'leitura.dart';

class ItemNota {
  /// `cProd`.
  final String codigo;
  final String? ean;

  /// `xProd`.
  final String descricao;

  /// `qCom` / `uCom` / `vUnCom`.
  final double quantidade;
  final String unidadeComercial;
  final double valorUnitario;
  final String? materialId;
  final String? materialNome;

  /// Quantidade já convertida pra unidade do estoque.
  final double? quantidadeEstoque;
  final SituacaoItemNota situacao;
  final MetodoCasamento? metodo;
  final String? movimentacaoId;

  /// Pergunta pendente, ex.: "Quantas unidades vêm em 1 CX?".
  final String? pergunta;

  const ItemNota({
    required this.codigo,
    this.ean,
    required this.descricao,
    required this.quantidade,
    required this.unidadeComercial,
    required this.valorUnitario,
    this.materialId,
    this.materialNome,
    this.quantidadeEstoque,
    this.situacao = SituacaoItemNota.confirmar,
    this.metodo,
    this.movimentacaoId,
    this.pergunta,
  });

  factory ItemNota.fromMap(Map<String, dynamic> d) => ItemNota(
    codigo: lerTexto(d['codigo']) ?? '',
    ean: lerTexto(d['ean']),
    descricao: lerTexto(d['descricao']) ?? '',
    quantidade: lerNum(d['quantidade']),
    unidadeComercial: lerTexto(d['unidadeComercial']) ?? '',
    valorUnitario: lerNum(d['valorUnitario']),
    materialId: lerTexto(d['materialId']),
    materialNome: lerTexto(d['materialNome']),
    quantidadeEstoque: lerNumOuNulo(d['quantidadeEstoque']),
    situacao: SituacaoItemNota.fromName(d['situacao'] as String?),
    metodo: MetodoCasamento.tryFromName(d['metodo'] as String?),
    movimentacaoId: lerTexto(d['movimentacaoId']),
    pergunta: lerTexto(d['pergunta']),
  );

  Map<String, dynamic> toMap() => semNulos({
    'codigo': codigo,
    'ean': ean,
    'descricao': descricao,
    'quantidade': quantidade,
    'unidadeComercial': unidadeComercial,
    'valorUnitario': valorUnitario,
    'materialId': materialId,
    'materialNome': materialNome,
    'quantidadeEstoque': quantidadeEstoque,
    'situacao': situacao.name,
    'metodo': metodo?.name,
    'movimentacaoId': movimentacaoId,
    'pergunta': pergunta,
  });

  ItemNota copyWith({
    String? materialId,
    String? materialNome,
    double? quantidadeEstoque,
    SituacaoItemNota? situacao,
    MetodoCasamento? metodo,
    String? movimentacaoId,
    String? pergunta,
    bool limparPergunta = false,
  }) {
    return ItemNota(
      codigo: codigo,
      ean: ean,
      descricao: descricao,
      quantidade: quantidade,
      unidadeComercial: unidadeComercial,
      valorUnitario: valorUnitario,
      materialId: materialId ?? this.materialId,
      materialNome: materialNome ?? this.materialNome,
      quantidadeEstoque: quantidadeEstoque ?? this.quantidadeEstoque,
      situacao: situacao ?? this.situacao,
      metodo: metodo ?? this.metodo,
      movimentacaoId: movimentacaoId ?? this.movimentacaoId,
      pergunta: limparPergunta ? null : (pergunta ?? this.pergunta),
    );
  }
}

/// Documento de `notas_fiscais/{chaveAcesso}` (sem chave: `CNPJ-numero`).
class NotaFiscal {
  final String id;
  final String? chaveAcesso;
  final String? fornecedorId;
  final String fornecedorNome;
  final String? cnpjEmitente;
  final String numero;
  final DateTime? emitidaEm;
  final List<ItemNota> itens;
  final StatusNota status;
  final List<String> movimentacaoIds;
  final String? arquivoNome;
  final DateTime? criadoEm;

  const NotaFiscal({
    required this.id,
    this.chaveAcesso,
    this.fornecedorId,
    required this.fornecedorNome,
    this.cnpjEmitente,
    required this.numero,
    this.emitidaEm,
    this.itens = const [],
    this.status = StatusNota.parcial,
    this.movimentacaoIds = const [],
    this.arquivoNome,
    this.criadoEm,
  });

  factory NotaFiscal.fromMap(String id, Map<String, dynamic> d) => NotaFiscal(
    id: id,
    chaveAcesso: lerTexto(d['chaveAcesso']),
    fornecedorId: lerTexto(d['fornecedorId']),
    fornecedorNome: lerTexto(d['fornecedorNome']) ?? '',
    cnpjEmitente: lerTexto(d['cnpjEmitente']),
    numero: lerTexto(d['numero']) ?? '',
    emitidaEm: lerData(d['emitidaEm']),
    itens: lerListaMapas(d['itens']).map(ItemNota.fromMap).toList(),
    status: StatusNota.fromName(d['status'] as String?),
    movimentacaoIds: lerListaTexto(d['movimentacaoIds']),
    arquivoNome: lerTexto(d['arquivoNome']),
    criadoEm: lerData(d['criadoEm']),
  );

  factory NotaFiscal.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      NotaFiscal.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => semNulos({
    'chaveAcesso': chaveAcesso,
    'fornecedorId': fornecedorId,
    'fornecedorNome': fornecedorNome,
    'cnpjEmitente': cnpjEmitente,
    'numero': numero,
    'emitidaEm': emitidaEm == null ? null : Timestamp.fromDate(emitidaEm!),
    'itens': itens.map((i) => i.toMap()).toList(),
    'status': status.name,
    'movimentacaoIds': movimentacaoIds,
    'arquivoNome': arquivoNome,
  });

  NotaFiscal copyWith({
    String? fornecedorId,
    String? fornecedorNome,
    List<ItemNota>? itens,
    StatusNota? status,
    List<String>? movimentacaoIds,
  }) {
    return NotaFiscal(
      id: id,
      chaveAcesso: chaveAcesso,
      fornecedorId: fornecedorId ?? this.fornecedorId,
      fornecedorNome: fornecedorNome ?? this.fornecedorNome,
      cnpjEmitente: cnpjEmitente,
      numero: numero,
      emitidaEm: emitidaEm,
      itens: itens ?? this.itens,
      status: status ?? this.status,
      movimentacaoIds: movimentacaoIds ?? this.movimentacaoIds,
      arquivoNome: arquivoNome,
      criadoEm: criadoEm,
    );
  }
}
