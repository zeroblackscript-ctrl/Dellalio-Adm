import 'package:xml/xml.dart';

import '../importacao/planilha.dart';
import '../models/leitura.dart';

class ItemNotaLido {
  final String codigo;
  final String? ean;
  final String descricao;
  final double quantidade;
  final String unidade;
  final double valorUnitario;

  const ItemNotaLido({
    required this.codigo,
    this.ean,
    required this.descricao,
    required this.quantidade,
    required this.unidade,
    required this.valorUnitario,
  });
}

/// Nota como veio (XML da NF-e ou DANFE lida pela IA).
class NotaLida {
  final String? chaveAcesso;
  final String? cnpjEmitente;
  final String nomeEmitente;
  final String? foneEmitente;
  final String numero;
  final DateTime? emitidaEm;
  final List<ItemNotaLido> itens;

  const NotaLida({
    this.chaveAcesso,
    this.cnpjEmitente,
    required this.nomeEmitente,
    this.foneEmitente,
    required this.numero,
    this.emitidaEm,
    required this.itens,
  });

  /// Chave de 44 dígitos; sem ela, `CNPJ-numero`. Dedup natural.
  String? get idDocumento {
    if (chaveAcesso != null && chaveAcesso!.length == 44) return chaveAcesso;
    if (cnpjEmitente != null && numero.isNotEmpty) return '$cnpjEmitente-$numero';
    return null;
  }
}

String _so(String? s) => (s ?? '').replaceAll(RegExp(r'\D'), '');

/// XML com `<nfeProc>`/`<NFe>`?
bool pareceXmlNfe(String texto) =>
    texto.contains('<nfeProc') || texto.contains('<NFe') || texto.contains(':NFe');

/// Parse do XML da NF-e (caminho principal, 100% confiável).
NotaLida lerXmlNfe(String xml) {
  final doc = XmlDocument.parse(xml);
  XmlElement? primeiro(XmlNode n, String nome) =>
      n.descendantElements.where((e) => e.localName == nome).firstOrNull;
  String? texto(XmlNode? n, String nome) =>
      n == null ? null : primeiro(n, nome)?.innerText.trim();

  final inf = primeiro(doc, 'infNFe');
  if (inf == null) throw const FormatException('XML sem infNFe');
  final chave = _so(inf.getAttribute('Id')?.replaceFirst('NFe', ''));
  final emit = primeiro(inf, 'emit');
  final ide = primeiro(inf, 'ide');

  final itens = <ItemNotaLido>[];
  for (final det in inf.childElements.where((e) => e.localName == 'det')) {
    final prod = primeiro(det, 'prod');
    if (prod == null) continue;
    final ean = texto(prod, 'cEAN');
    itens.add(ItemNotaLido(
      codigo: texto(prod, 'cProd') ?? '',
      ean: ean == null || ean.isEmpty || ean.toUpperCase() == 'SEM GTIN' ? null : ean,
      descricao: texto(prod, 'xProd') ?? '',
      quantidade: lerNumeroBr(texto(prod, 'qCom') ?? '') ?? 0,
      unidade: texto(prod, 'uCom') ?? 'UN',
      valorUnitario: lerNumeroBr(texto(prod, 'vUnCom') ?? '') ?? 0,
    ));
  }

  return NotaLida(
    chaveAcesso: chave.length == 44 ? chave : null,
    cnpjEmitente: _so(texto(emit, 'CNPJ') ?? texto(emit, 'CPF')),
    nomeEmitente: texto(emit, 'xFant') ?? texto(emit, 'xNome') ?? 'Fornecedor',
    foneEmitente: texto(emit, 'fone'),
    numero: texto(ide, 'nNF') ?? '',
    emitidaEm: DateTime.tryParse(texto(ide, 'dhEmi') ?? texto(ide, 'dEmi') ?? ''),
    itens: itens,
  );
}

/// JSON devolvido pela IA (`lerNotaComIA`).
NotaLida notaDoJson(Map<String, dynamic> r) => NotaLida(
  chaveAcesso: _so(lerTexto(r['chaveAcesso'])).length == 44 ? _so(lerTexto(r['chaveAcesso'])) : null,
  cnpjEmitente: _so(lerTexto(r['cnpjEmitente'])).isEmpty ? null : _so(lerTexto(r['cnpjEmitente'])),
  nomeEmitente: lerTexto(r['nomeEmitente']) ?? 'Fornecedor',
  numero: lerTexto(r['numero']) ?? '',
  emitidaEm: lerData(r['emitidaEm']),
  itens: lerListaMapas(r['itens'])
      .map((i) => ItemNotaLido(
            codigo: lerTexto(i['codigo']) ?? '',
            descricao: lerTexto(i['descricao']) ?? '',
            quantidade: lerNum(i['quantidade']),
            unidade: lerTexto(i['unidade']) ?? 'UN',
            valorUnitario: lerNum(i['valorUnitario']),
          ))
      .where((i) => i.descricao.isNotEmpty && i.quantidade > 0)
      .toList(),
);
