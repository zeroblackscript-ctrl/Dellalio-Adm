import '../models/models.dart';
import '../util/datas.dart';
import '../util/quantidade.dart';

/// Número da NF a partir do id da nota: chave de 44 dígitos (posições do
/// nNF) ou `CNPJ-numero`.
String? numeroNota(String? notaId) {
  if (notaId == null) return null;
  if (notaId.length == 44) {
    final n = int.tryParse(notaId.substring(25, 34));
    return n?.toString();
  }
  final partes = notaId.split('-');
  return partes.length > 1 ? partes.last : null;
}

/// Título do histórico: "Saída · Painel TV Souza", "Entrada · Compra".
String tituloMov(Movimentacao m) {
  final quem = m.tipo == TipoMovimentacao.entrada || m.tipo == TipoMovimentacao.perda ||
          m.tipo == TipoMovimentacao.ajuste
      ? m.motivo
      : (m.paraQuem ?? m.motivo);
  return quem.isEmpty ? m.tipo.rotulo : '${m.tipo.rotulo} · $quem';
}

/// Linha "origem · responsável · data" do histórico.
String detalheMov(Movimentacao m) {
  final quando = fmtDiaHora(m.criadoEm);
  if (m.notaFiscalId != null) {
    final nf = numeroNota(m.notaFiscalId);
    return ['NF ${nf ?? ''}'.trim(), ?m.fornecedorNome, quando].join(' · ');
  }
  final origem = switch (m.origem) {
    OrigemMovimentacao.listaCorte => 'Lista de corte',
    OrigemMovimentacao.projetoCortado => 'Produção',
    OrigemMovimentacao.notaFiscal => 'Nota fiscal',
    OrigemMovimentacao.sistema => 'Sistema',
    OrigemMovimentacao.manual => m.tipo == TipoMovimentacao.perda || m.tipo == TipoMovimentacao.ajuste
        ? 'Inventário'
        : 'Manual',
  };
  return [origem, m.responsavelNome, quando].join(' · ');
}

/// Linha secundária da visão geral: "Cozinha · Rodrigues · Sistema",
/// "NF 48213 · Madeireira Central", "Chapa empenada · Ana".
String resumoMov(Movimentacao m) {
  if (m.notaFiscalId != null) {
    return ['NF ${numeroNota(m.notaFiscalId) ?? ''}'.trim(), ?m.fornecedorNome].join(' · ');
  }
  final primeiro = m.tipo == TipoMovimentacao.perda || m.tipo == TipoMovimentacao.ajuste
      ? m.motivo
      : (m.paraQuem ?? m.motivo);
  return [primeiro, m.responsavelNome].where((s) => s.isNotEmpty).join(' · ');
}

/// Quantidade com sinal do histórico ("−2 ch", "+5 ch", "3 ch" na reserva).
String qtdMov(Movimentacao m) => m.tipo == TipoMovimentacao.reserva
    ? fmtQtd(m.quantidade, m.unidade)
    : fmtQtdComSinal(m.quantidadeComSinal, m.unidade);

/// "DinaBox · hoje 08:12 · 8 itens".
String subtituloLista(ListaCorte l) =>
    '${l.software.rotulo} · ${fmtQuando(l.criadoEm)} · ${l.itens.length} '
    '${l.itens.length == 1 ? 'item' : 'itens'}';

/// Valor compacto: "48,2 mil", "1,3 mi", "812".
(String, String?) valorCompacto(double v) {
  if (v.abs() >= 1e6) return (fmtNumero(double.parse((v / 1e6).toStringAsFixed(1))), 'mi');
  if (v.abs() >= 1e3) return (fmtNumero(double.parse((v / 1e3).toStringAsFixed(1))), 'mil');
  return (fmtNumero(v.roundToDouble()), null);
}
