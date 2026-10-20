import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../notas/fonte_notas.dart';
import '../notas/importador_notas.dart';
import 'importador_listas.dart';
import 'vigia_pasta.dart';

/// Resultado de uma importação manual (arrastar ou botão).
enum TipoImportado { lista, nota, repetido, falhou }

/// Liga as fontes (pastas vigiadas, arrastar, botão) aos importadores.
/// Tudo entra numa fila única: um arquivo por vez, na ordem de chegada —
/// uma lista nova nunca reserva antes de uma anterior, e uma nota nunca
/// realoca no meio da leitura de uma lista.
class Automacao {
  Automacao._();
  static final Automacao instancia = Automacao._();

  static const extensoesListas = {'pdf', 'csv', 'xlsx', 'xls'};
  static const extensoesNotas = {'xml', 'pdf', 'jpg', 'jpeg', 'png'};

  late final VigiaPasta vigiaListas = VigiaPasta(
    chavePreferencia: 'pasta_listas',
    subpastaPadrao: r'Dellalio\Listas',
    extensoes: extensoesListas,
    aoChegar: (f) async => importarLista(f),
  );

  /// Fonte das notas. Fase 2: trocar/somar uma `FonteSefaz` aqui.
  final FontePasta fonteNotas = FontePasta();
  StreamSubscription<ArquivoNota>? _subNotas;

  Future<void> _fila = Future.value();
  bool _iniciada = false;

  Future<void> iniciar() async {
    if (_iniciada) return;
    _iniciada = true;
    _subNotas = fonteNotas.arquivos.listen(
      (a) => _enfileirar(
        () => ImportadorNotas.instancia.importarBytes(a.nome, a.bytes),
      ).catchError((_) => null),
    );
    await vigiaListas.iniciar();
    await fonteNotas.iniciar();
  }

  Future<void> parar() async {
    await vigiaListas.parar();
    await fonteNotas.parar();
    await _subNotas?.cancel();
    _iniciada = false;
  }

  Future<T?> _enfileirar<T>(Future<T?> Function() tarefa) {
    final c = Completer<T?>();
    _fila = _fila.then((_) async {
      try {
        c.complete(await tarefa());
      } catch (e, s) {
        debugPrint('Importação falhou: $e\n$s');
        c.completeError(e);
      }
    });
    return c.future;
  }

  Future<String?> importarLista(File arquivo) =>
      _enfileirar(() => ImportadorListas.instancia.importar(arquivo));

  bool aceita(String caminho) {
    final ext = p.extension(caminho).toLowerCase().replaceFirst('.', '');
    return vigiaListas.aceita(caminho) || extensoesNotas.contains(ext);
  }

  /// Arrastar e soltar / botão: decide pelo conteúdo se é lista ou nota
  /// (XML com `<nfeProc>`/`<NFe>`, PDF com "DANFE" ou foto → nota).
  Future<TipoImportado> importarArquivo(File arquivo) async {
    try {
      final bytes = await arquivo.readAsBytes();
      final nome = p.basename(arquivo.path);
      if (ImportadorNotas.ehNota(nome, bytes)) {
        final id = await _enfileirar(() => ImportadorNotas.instancia.importarBytes(nome, bytes));
        return id == null ? TipoImportado.repetido : TipoImportado.nota;
      }
      final id = await _enfileirar(
        () => ImportadorListas.instancia.importarBytes(nome, bytes, caminho: arquivo.path),
      );
      return id == null ? TipoImportado.repetido : TipoImportado.lista;
    } catch (_) {
      return TipoImportado.falhou;
    }
  }
}
