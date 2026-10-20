/// Enums do estoque. Cada um grava no Firestore pelo `name` e volta pelo
/// `fromName`, que nunca lança: valor desconhecido cai num padrão seguro.
library;

T _porNome<T extends Enum>(List<T> valores, String? nome, T padrao) {
  for (final v in valores) {
    if (v.name == nome) return v;
  }
  return padrao;
}

enum CategoriaMaterial {
  chapa('Chapa', 'Chapas'),
  sobra('Sobra', 'Sobras'),
  fita('Fita', 'Fitas'),
  ferragem('Ferragem', 'Ferragens'),
  acessorio('Acessório', 'Acessórios'),
  insumo('Insumo', 'Insumos');

  const CategoriaMaterial(this.rotulo, this.plural);
  final String rotulo;
  final String plural;

  static CategoriaMaterial fromName(String? nome) =>
      _porNome(values, nome, CategoriaMaterial.insumo);

  static CategoriaMaterial? tryFromName(String? nome) =>
      values.where((v) => v.name == nome).firstOrNull;
}

enum UnidadeEstoque {
  ch('ch', 'chapa', 'chapas', inteira: true),
  m('m', 'metro', 'metros'),
  un('un', 'unidade', 'unidades', inteira: true),
  par('par', 'par', 'pares', inteira: true),
  m2('m²', 'm²', 'm²'),
  kg('kg', 'kg', 'kg'),
  l('l', 'litro', 'litros'),
  cx('cx', 'caixa', 'caixas', inteira: true);

  const UnidadeEstoque(
    this.sigla,
    this.singular,
    this.plural, {
    this.inteira = false,
  });

  /// Como aparece ao lado de um número ("14 ch", "212 m").
  final String sigla;
  final String singular;
  final String plural;

  /// Quantidades de `ch`, `un`, `par` e `cx` são sempre inteiras.
  final bool inteira;

  static UnidadeEstoque fromName(String? nome) =>
      _porNome(values, nome, UnidadeEstoque.un);

  static UnidadeEstoque? tryFromName(String? nome) =>
      values.where((v) => v.name == nome).firstOrNull;
}

enum TipoMovimentacao {
  entrada('Entrada'),
  saida('Saída'),
  reserva('Reserva'),
  liberacaoReserva('Liberação de reserva'),
  ajuste('Ajuste'),
  perda('Perda');

  const TipoMovimentacao(this.rotulo);
  final String rotulo;

  static TipoMovimentacao fromName(String? nome) =>
      _porNome(values, nome, TipoMovimentacao.ajuste);
}

enum OrigemMovimentacao {
  listaCorte('Lista de corte'),
  notaFiscal('Nota fiscal'),
  projetoCortado('Produção'),
  manual('Manual'),
  sistema('Sistema');

  const OrigemMovimentacao(this.rotulo);
  final String rotulo;

  static OrigemMovimentacao fromName(String? nome) =>
      _porNome(values, nome, OrigemMovimentacao.manual);
}

enum SoftwareLista {
  dinabox('DinaBox'),
  planilha('Planilha'),
  ia('IA'),
  generico('PDF'),
  desconhecido('Desconhecido');

  const SoftwareLista(this.rotulo);
  final String rotulo;

  static SoftwareLista fromName(String? nome) =>
      _porNome(values, nome, SoftwareLista.desconhecido);
}

enum StatusLista {
  lida('Lida'),
  // Tudo reservado na chegada: pra quem usa, é o mesmo que "pronta".
  reservada('Pronta'),
  aguardandoCompra('Aguardando compra'),
  pronta('Pronta'),
  cortada('Cortada'),
  cancelada('Cancelada');

  const StatusLista(this.rotulo);
  final String rotulo;

  /// Listas que ainda seguram reservas no estoque.
  bool get ativa =>
      this == lida || this == reservada || this == aguardandoCompra ||
      this == pronta;

  static StatusLista fromName(String? nome) =>
      _porNome(values, nome, StatusLista.lida);
}

enum SituacaoItem {
  ok('Reservado'),
  parcial('Parcial'),
  falta('Falta'),
  confirmar('Confirmar');

  const SituacaoItem(this.rotulo);
  final String rotulo;

  static SituacaoItem fromName(String? nome) =>
      _porNome(values, nome, SituacaoItem.confirmar);
}

enum MetodoCasamento {
  ref,
  apelido,
  aproximado,
  ia,
  criado,
  manual;

  static MetodoCasamento? tryFromName(String? nome) =>
      values.where((v) => v.name == nome).firstOrNull;
}

enum StatusPedido {
  rascunho('Rascunho'),
  enviado('Enviado'),
  recebido('Recebido'),
  recebidoParcial('Recebido parcial');

  const StatusPedido(this.rotulo);
  final String rotulo;

  static StatusPedido fromName(String? nome) =>
      _porNome(values, nome, StatusPedido.rascunho);
}

enum OrigemItemPedido {
  lista,
  minimo;

  static OrigemItemPedido fromName(String? nome) =>
      _porNome(values, nome, OrigemItemPedido.lista);
}

enum StatusNota {
  lancada('Lançada'),
  parcial('Parcial');

  const StatusNota(this.rotulo);
  final String rotulo;

  static StatusNota fromName(String? nome) =>
      _porNome(values, nome, StatusNota.parcial);
}

enum SituacaoItemNota {
  lancado,
  confirmar;

  static SituacaoItemNota fromName(String? nome) =>
      _porNome(values, nome, SituacaoItemNota.confirmar);
}

enum TipoAviso {
  listaLida,
  confirmar,
  pedidoPronto,
  listaPronta,
  notaLancada,
  alerta;

  static TipoAviso fromName(String? nome) =>
      _porNome(values, nome, TipoAviso.alerta);
}
