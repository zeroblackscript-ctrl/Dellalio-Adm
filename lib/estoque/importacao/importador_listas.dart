import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/models.dart';
import '../services/aviso_service.dart';
import '../services/casamento_service.dart';
import 'arquivo_entrada.dart';
import 'leitor.dart';
import 'leitor_dinabox.dart';
import 'leitor_generico.dart';
import 'leitor_ia.dart';
import 'leitor_planilha.dart';

/// Ponto único de entrada de listas: pasta vigiada, arrastar e soltar e o
/// botão "Importar arquivo" chamam todos [importar].
class ImportadorListas {
  ImportadorListas({
    FirebaseFirestore? db,
    List<LeitorLista>? leitores,
    LeitorLista? leitorIA,
    this.usarStorage = true,
    Future<void> Function(String listaId)? aposGravar,
  }) : _db = db ?? FirebaseFirestore.instance,
       _leitores = leitores ?? [LeitorDinabox(), LeitorPlanilha(), LeitorGenerico()],
       _leitorIA = leitorIA ?? LeitorIA(),
       _aposGravar = aposGravar ?? CasamentoService.processar;

  static final ImportadorListas instancia = ImportadorListas();

  final FirebaseFirestore _db;
  final List<LeitorLista> _leitores;
  final LeitorLista _leitorIA;
  final bool usarStorage;
  final Future<void> Function(String listaId) _aposGravar;

  /// Hashes sendo importados agora (pasta + drop do mesmo arquivo juntos).
  final Set<String> _emAndamento = {};

  static const int _limiteTexto = 900 * 1024;

  static String hashDe(Uint8List bytes) => sha256.convert(bytes).toString();

  /// Retorna o id da lista criada, ou `null` se já tinha sido importada.
  Future<String?> importar(File arquivo) async => importarBytes(
    p.basename(arquivo.path),
    await arquivo.readAsBytes(),
    caminho: arquivo.path,
  );

  Future<String?> importarBytes(
    String nome,
    Uint8List bytes, {
    String? caminho,
  }) async {
    final hash = hashDe(bytes);
    if (!_emAndamento.add(hash)) return null;
    try {
      final ref = _db.collection('listas_corte').doc(hash);
      // Id = hash: o mesmo arquivo nunca entra duas vezes, nem vindo de
      // duas máquinas ao mesmo tempo. Ignora em silêncio.
      if ((await ref.get()).exists) return null;
      final antigo = await _db
          .collection('listas_corte')
          .where('arquivoHash', isEqualTo: hash)
          .limit(1)
          .get();
      if (antigo.docs.isNotEmpty) return null;

      final entrada = ArquivoEntrada.deBytes(nome, bytes);
      final lida = await ler(entrada);
      final (projeto, cliente) = _nomes(lida, nome);

      String? texto = lida?.textoExtraido ?? entrada.texto;
      String? textoUrl;
      if (utf8.encode(texto).length > _limiteTexto) {
        textoUrl = await _subir(
          'listas_corte/$hash/texto.txt',
          Uint8List.fromList(utf8.encode(texto)),
          'text/plain; charset=utf-8',
        );
        texto = texto.substring(0, 200 * 1024);
      }
      final arquivoUrl = await _subir(
        'listas_corte/$hash/$nome',
        bytes,
        entrada.ehPdf ? 'application/pdf' : 'application/octet-stream',
      );

      final lista = ListaCorte(
        id: hash,
        arquivoNome: nome,
        arquivoHash: hash,
        arquivoCaminho: caminho,
        arquivoUrl: arquivoUrl,
        software: lida?.software ?? SoftwareLista.desconhecido,
        textoExtraido: texto,
        textoExtraidoUrl: textoUrl,
        clienteNome: cliente,
        projetoNome: projeto,
        status: StatusLista.lida,
        itens: [for (final i in lida?.itens ?? const <ItemLido>[]) itemDe(i)],
      );

      final criada = await _db.runTransaction<bool>((tx) async {
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, {...lista.toMap(), 'criadoEm': FieldValue.serverTimestamp()});
        return true;
      });
      if (!criada) return null;

      if (lista.itens.isEmpty) {
        await AvisoService(db: _db).registrar(
          TipoAviso.alerta,
          'Não consegui ler os itens de "$nome". O arquivo ficou salvo em '
          'Listas de corte pra conferir.',
          listaCorteId: hash,
        );
      }
      await _aposGravar(hash);
      return hash;
    } finally {
      _emAndamento.remove(hash);
    }
  }

  /// Pergunta a todos os leitores, tenta do melhor pro pior; aceita o
  /// primeiro com confiança ≥ 0,7 e itens. A IA é sempre a última; se ela
  /// falhar, fica o melhor resultado parcial.
  Future<ListaLida?> ler(ArquivoEntrada entrada) async {
    final notas = <(LeitorLista, double)>[];
    for (final l in _leitores) {
      try {
        final n = await l.reconhece(entrada);
        if (n > 0) notas.add((l, n));
      } catch (_) {}
    }
    notas.sort((a, b) => b.$2.compareTo(a.$2));

    ListaLida? reserva;
    for (final (leitor, _) in notas) {
      try {
        final r = await leitor.ler(entrada);
        if (r.itens.isNotEmpty && r.confianca >= 0.7) return r;
        if (r.itens.isNotEmpty && (reserva == null || r.confianca > reserva.confianca)) {
          reserva = r;
        }
      } catch (e) {
        debugPrint('Leitor ${leitor.nome} falhou em ${entrada.nome}: $e');
      }
    }
    try {
      if (await _leitorIA.reconhece(entrada) > 0) {
        final r = await _leitorIA.ler(entrada);
        if (r.itens.isNotEmpty) return r;
      }
    } catch (e) {
      debugPrint('IA não leu ${entrada.nome}: $e');
    }
    return reserva;
  }

  /// Item bruto: quantidade em estoque só existe depois do casamento.
  static ItemListaCorte itemDe(ItemLido i) => ItemListaCorte(
    descricaoOriginal: i.descricao,
    refFornecedor: i.refFornecedor,
    fornecedorNome: i.fornecedorNome,
    categoria: i.categoria,
    quantidadeOriginal: i.quantidade,
    unidadeOriginal: i.unidade,
    larguraMm: i.larguraMm,
    alturaMm: i.alturaMm,
    espessuraMm: i.espessuraMm,
    custoUnitario: i.custoUnitario,
  );

  /// (projeto, cliente). Sem nada no arquivo, deriva do nome:
  /// `cozinha_silva.pdf` → "Cozinha Silva".
  static (String?, String?) _nomes(ListaLida? lida, String arquivo) {
    if (lida?.projetoNome != null || lida?.clienteNome != null) {
      return (lida?.projetoNome, lida?.clienteNome);
    }
    return (nomeDoArquivo(arquivo), null);
  }

  static String nomeDoArquivo(String arquivo) {
    const ruido = {'lista', 'listas', 'compras', 'compra', 'corte', 'de', 'da', 'do', 'dinabox', 'materiais', 'final', 'v1', 'v2'};
    final palavras = p
        .basenameWithoutExtension(arquivo)
        .split(RegExp(r'[_\-\s.]+'))
        .where((w) => w.isNotEmpty && !ruido.contains(w.toLowerCase()))
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .toList();
    return palavras.isEmpty ? p.basenameWithoutExtension(arquivo) : palavras.join(' ');
  }

  Future<String?> _subir(String caminho, Uint8List bytes, String tipo) async {
    if (!usarStorage) return null;
    try {
      final ref = FirebaseStorage.instance.ref(caminho);
      await ref.putData(bytes, SettableMetadata(contentType: tipo));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Storage indisponível ($caminho): $e');
      return null;
    }
  }
}
