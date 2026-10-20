import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'importador_listas.dart';
import 'vigia_pasta.dart';

/// Liga os vigias de pasta aos importadores. Tudo que chega (pasta,
/// arrastar, botão) entra numa fila única: um arquivo por vez, na ordem de
/// chegada — assim uma lista nova nunca reserva antes de uma anterior.
class Automacao {
  Automacao._();
  static final Automacao instancia = Automacao._();

  static const extensoesListas = {'pdf', 'csv', 'xlsx', 'xls'};

  late final VigiaPasta vigiaListas = VigiaPasta(
    chavePreferencia: 'pasta_listas',
    subpastaPadrao: r'Dellalio\Listas',
    extensoes: extensoesListas,
    aoChegar: importarLista,
  );

  Future<void> _fila = Future.value();
  bool _iniciada = false;

  Future<void> iniciar() async {
    if (_iniciada) return;
    _iniciada = true;
    await vigiaListas.iniciar();
  }

  /// Enfileira e devolve o resultado do importador.
  Future<T?> _enfileirar<T>(Future<T?> Function() tarefa) {
    final c = Completer<T?>();
    _fila = _fila.then((_) async {
      try {
        c.complete(await tarefa());
      } catch (e, s) {
        debugPrint('Importação falhou: $e\n$s');
        c.complete(null);
      }
    });
    return c.future;
  }

  Future<String?> importarLista(File arquivo) =>
      _enfileirar(() => ImportadorListas.instancia.importar(arquivo));

  /// Arrastar e soltar / botão: decide pelo conteúdo (etapa 04 trata notas).
  Future<String?> importarArquivo(File arquivo) => importarLista(arquivo);
}
