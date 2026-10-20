import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'leitura.dart';

/// Candidato sugerido para um item `confirmar`.
class SugestaoMaterial {
  final String materialId;
  final String nome;
  final double score;

  const SugestaoMaterial({
    required this.materialId,
    required this.nome,
    required this.score,
  });

  factory SugestaoMaterial.fromMap(Map<String, dynamic> d) => SugestaoMaterial(
    materialId: lerTexto(d['materialId']) ?? '',
    nome: lerTexto(d['nome']) ?? '',
    score: lerNum(d['score']),
  );

  Map<String, dynamic> toMap() => {
    'materialId': materialId,
    'nome': nome,
    'score': score,
  };
}

class ItemListaCorte {
  final String descricaoOriginal;
  final String? refFornecedor;
  final String? fornecedorNome;
  final CategoriaMaterial? categoria;
  final double quantidadeOriginal;
  final String unidadeOriginal;

  /// Já na unidade do estoque (depois do casamento).
  final double quantidade;
  final UnidadeEstoque? unidade;
  final double? larguraMm;
  final double? alturaMm;
  final double? espessuraMm;
  final double? custoUnitario;
  final String? materialId;

  /// Nome do material casado, desnormalizado pra listar rápido.
  final String? materialNome;
  final double confianca;
  final MetodoCasamento? metodoCasamento;
  final SituacaoItem situacao;
  final double qtdReservada;
  final double qtdFaltante;
  final List<SugestaoMaterial> sugestoes;

  /// Explicação curta da conversão ("veio como 11,4 m² → 3 chapas").
  final String? observacao;

  /// Conversão feita com medida padrão de chapa: conferir.
  final bool conferirConversao;

  const ItemListaCorte({
    required this.descricaoOriginal,
    this.refFornecedor,
    this.fornecedorNome,
    this.categoria,
    required this.quantidadeOriginal,
    required this.unidadeOriginal,
    this.quantidade = 0,
    this.unidade,
    this.larguraMm,
    this.alturaMm,
    this.espessuraMm,
    this.custoUnitario,
    this.materialId,
    this.materialNome,
    this.confianca = 0,
    this.metodoCasamento,
    this.situacao = SituacaoItem.confirmar,
    this.qtdReservada = 0,
    this.qtdFaltante = 0,
    this.sugestoes = const [],
    this.observacao,
    this.conferirConversao = false,
  });

  bool get casado => materialId != null && situacao != SituacaoItem.confirmar;

  factory ItemListaCorte.fromMap(Map<String, dynamic> d) => ItemListaCorte(
    descricaoOriginal: lerTexto(d['descricaoOriginal']) ?? '',
    refFornecedor: lerTexto(d['refFornecedor']),
    fornecedorNome: lerTexto(d['fornecedorNome']),
    categoria: CategoriaMaterial.tryFromName(d['categoria'] as String?),
    quantidadeOriginal: lerNum(d['quantidadeOriginal']),
    unidadeOriginal: lerTexto(d['unidadeOriginal']) ?? '',
    quantidade: lerNum(d['quantidade']),
    unidade: UnidadeEstoque.tryFromName(d['unidade'] as String?),
    larguraMm: lerNumOuNulo(d['larguraMm']),
    alturaMm: lerNumOuNulo(d['alturaMm']),
    espessuraMm: lerNumOuNulo(d['espessuraMm']),
    custoUnitario: lerNumOuNulo(d['custoUnitario']),
    materialId: lerTexto(d['materialId']),
    materialNome: lerTexto(d['materialNome']),
    confianca: lerNum(d['confianca']),
    metodoCasamento: MetodoCasamento.tryFromName(
      d['metodoCasamento'] as String?,
    ),
    situacao: SituacaoItem.fromName(d['situacao'] as String?),
    qtdReservada: lerNum(d['qtdReservada']),
    qtdFaltante: lerNum(d['qtdFaltante']),
    sugestoes: lerListaMapas(
      d['sugestoes'],
    ).map(SugestaoMaterial.fromMap).toList(),
    observacao: lerTexto(d['observacao']),
    conferirConversao: d['conferirConversao'] == true,
  );

  Map<String, dynamic> toMap() => semNulos({
    'descricaoOriginal': descricaoOriginal,
    'refFornecedor': refFornecedor,
    'fornecedorNome': fornecedorNome,
    'categoria': categoria?.name,
    'quantidadeOriginal': quantidadeOriginal,
    'unidadeOriginal': unidadeOriginal,
    'quantidade': quantidade,
    'unidade': unidade?.name,
    'larguraMm': larguraMm,
    'alturaMm': alturaMm,
    'espessuraMm': espessuraMm,
    'custoUnitario': custoUnitario,
    'materialId': materialId,
    'materialNome': materialNome,
    'confianca': confianca,
    'metodoCasamento': metodoCasamento?.name,
    'situacao': situacao.name,
    'qtdReservada': qtdReservada,
    'qtdFaltante': qtdFaltante,
    'sugestoes': sugestoes.map((s) => s.toMap()).toList(),
    'observacao': observacao,
    'conferirConversao': conferirConversao,
  });

  /// Campos anuláveis que precisam poder voltar a `null` usam os `limpar*`.
  ItemListaCorte copyWith({
    String? refFornecedor,
    CategoriaMaterial? categoria,
    double? quantidade,
    UnidadeEstoque? unidade,
    String? materialId,
    String? materialNome,
    double? confianca,
    MetodoCasamento? metodoCasamento,
    SituacaoItem? situacao,
    double? qtdReservada,
    double? qtdFaltante,
    List<SugestaoMaterial>? sugestoes,
    String? observacao,
    bool? conferirConversao,
    bool limparMaterial = false,
  }) {
    return ItemListaCorte(
      descricaoOriginal: descricaoOriginal,
      refFornecedor: refFornecedor ?? this.refFornecedor,
      fornecedorNome: fornecedorNome,
      categoria: categoria ?? this.categoria,
      quantidadeOriginal: quantidadeOriginal,
      unidadeOriginal: unidadeOriginal,
      quantidade: quantidade ?? this.quantidade,
      unidade: unidade ?? this.unidade,
      larguraMm: larguraMm,
      alturaMm: alturaMm,
      espessuraMm: espessuraMm,
      custoUnitario: custoUnitario,
      materialId: limparMaterial ? null : (materialId ?? this.materialId),
      materialNome: limparMaterial ? null : (materialNome ?? this.materialNome),
      confianca: confianca ?? this.confianca,
      metodoCasamento: limparMaterial
          ? null
          : (metodoCasamento ?? this.metodoCasamento),
      situacao: situacao ?? this.situacao,
      qtdReservada: qtdReservada ?? this.qtdReservada,
      qtdFaltante: qtdFaltante ?? this.qtdFaltante,
      sugestoes: sugestoes ?? this.sugestoes,
      observacao: observacao ?? this.observacao,
      conferirConversao: conferirConversao ?? this.conferirConversao,
    );
  }
}

class ResumoLista {
  final int ok;
  final int parcial;
  final int falta;
  final int confirmar;

  const ResumoLista({
    this.ok = 0,
    this.parcial = 0,
    this.falta = 0,
    this.confirmar = 0,
  });

  int get total => ok + parcial + falta + confirmar;

  factory ResumoLista.de(List<ItemListaCorte> itens) {
    int c(SituacaoItem s) => itens.where((i) => i.situacao == s).length;
    return ResumoLista(
      ok: c(SituacaoItem.ok),
      parcial: c(SituacaoItem.parcial),
      falta: c(SituacaoItem.falta),
      confirmar: c(SituacaoItem.confirmar),
    );
  }

  factory ResumoLista.fromMap(Map<String, dynamic>? d) => ResumoLista(
    ok: lerNum(d?['ok']).toInt(),
    parcial: lerNum(d?['parcial']).toInt(),
    falta: lerNum(d?['falta']).toInt(),
    confirmar: lerNum(d?['confirmar']).toInt(),
  );

  Map<String, dynamic> toMap() => {
    'ok': ok,
    'parcial': parcial,
    'falta': falta,
    'confirmar': confirmar,
  };

  @override
  bool operator ==(Object other) =>
      other is ResumoLista &&
      other.ok == ok &&
      other.parcial == parcial &&
      other.falta == falta &&
      other.confirmar == confirmar;

  @override
  int get hashCode => Object.hash(ok, parcial, falta, confirmar);
}

/// Documento de `listas_corte/{id}`.
class ListaCorte {
  final String id;
  final String arquivoNome;
  final String arquivoHash;

  /// Caminho local do arquivo na máquina que importou (pra "Ver PDF").
  final String? arquivoCaminho;

  /// Cópia no Storage, quando houver (abre em qualquer máquina).
  final String? arquivoUrl;
  final SoftwareLista software;
  final String? textoExtraido;

  /// Texto bruto grande demais pro documento fica no Storage.
  final String? textoExtraidoUrl;
  final String? clienteNome;
  final String? projetoNome;
  final StatusLista status;
  final List<ItemListaCorte> itens;
  final ResumoLista resumo;
  final DateTime? criadoEm;
  final DateTime? cortadaEm;
  final String? cortadaPor;

  const ListaCorte({
    required this.id,
    required this.arquivoNome,
    required this.arquivoHash,
    this.arquivoCaminho,
    this.arquivoUrl,
    required this.software,
    this.textoExtraido,
    this.textoExtraidoUrl,
    this.clienteNome,
    this.projetoNome,
    required this.status,
    this.itens = const [],
    this.resumo = const ResumoLista(),
    this.criadoEm,
    this.cortadaEm,
    this.cortadaPor,
  });

  /// "Cozinha · Rodrigues" — projeto e cliente, o que houver.
  String get titulo {
    final partes = [projetoNome, clienteNome].whereType<String>().toList();
    return partes.isEmpty ? arquivoNome : partes.join(' · ');
  }

  factory ListaCorte.fromMap(String id, Map<String, dynamic> d) {
    final itens = lerListaMapas(d['itens']).map(ItemListaCorte.fromMap).toList();
    return ListaCorte(
      id: id,
      arquivoNome: lerTexto(d['arquivoNome']) ?? '',
      arquivoHash: lerTexto(d['arquivoHash']) ?? '',
      arquivoCaminho: lerTexto(d['arquivoCaminho']),
      arquivoUrl: lerTexto(d['arquivoUrl']),
      software: SoftwareLista.fromName(d['software'] as String?),
      textoExtraido: lerTexto(d['textoExtraido']),
      textoExtraidoUrl: lerTexto(d['textoExtraidoUrl']),
      clienteNome: lerTexto(d['clienteNome']),
      projetoNome: lerTexto(d['projetoNome']),
      status: StatusLista.fromName(d['status'] as String?),
      itens: itens,
      resumo: d['resumo'] is Map
          ? ResumoLista.fromMap(Map<String, dynamic>.from(d['resumo'] as Map))
          : ResumoLista.de(itens),
      criadoEm: lerData(d['criadoEm']),
      cortadaEm: lerData(d['cortadaEm']),
      cortadaPor: lerTexto(d['cortadaPor']),
    );
  }

  factory ListaCorte.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ListaCorte.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => semNulos({
    'arquivoNome': arquivoNome,
    'arquivoHash': arquivoHash,
    'arquivoCaminho': arquivoCaminho,
    'arquivoUrl': arquivoUrl,
    'software': software.name,
    'textoExtraido': textoExtraido,
    'textoExtraidoUrl': textoExtraidoUrl,
    'clienteNome': clienteNome,
    'projetoNome': projetoNome,
    'status': status.name,
    'itens': itens.map((i) => i.toMap()).toList(),
    'resumo': ResumoLista.de(itens).toMap(),
    'cortadaPor': cortadaPor,
  });

  ListaCorte copyWith({
    StatusLista? status,
    List<ItemListaCorte>? itens,
    String? clienteNome,
    String? projetoNome,
    String? arquivoUrl,
    DateTime? cortadaEm,
    String? cortadaPor,
  }) {
    final novos = itens ?? this.itens;
    return ListaCorte(
      id: id,
      arquivoNome: arquivoNome,
      arquivoHash: arquivoHash,
      arquivoCaminho: arquivoCaminho,
      arquivoUrl: arquivoUrl ?? this.arquivoUrl,
      software: software,
      textoExtraido: textoExtraido,
      textoExtraidoUrl: textoExtraidoUrl,
      clienteNome: clienteNome ?? this.clienteNome,
      projetoNome: projetoNome ?? this.projetoNome,
      status: status ?? this.status,
      itens: novos,
      resumo: ResumoLista.de(novos),
      criadoEm: criadoEm,
      cortadaEm: cortadaEm ?? this.cortadaEm,
      cortadaPor: cortadaPor ?? this.cortadaPor,
    );
  }
}
