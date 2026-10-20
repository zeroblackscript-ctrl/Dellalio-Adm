import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EstadoVigia {
  final String? caminho;
  final bool ativo;
  final String? erro;
  const EstadoVigia({this.caminho, this.ativo = false, this.erro});
}

/// Vigia uma pasta e entrega cada arquivo novo (já estável) ao [aoChegar].
/// A pasta é configurável por máquina (`shared_preferences`); erro de caminho
/// vira [estado.erro] pra tela de configurações — nunca derruba o app.
class VigiaPasta {
  VigiaPasta({
    required this.chavePreferencia,
    required this.subpastaPadrao,
    required this.extensoes,
    required this.aoChegar,
  });

  /// Chave no `shared_preferences` ("pasta_listas").
  final String chavePreferencia;

  /// Dentro de Documentos ("Dellalio\Listas").
  final String subpastaPadrao;
  final Set<String> extensoes;
  final Future<void> Function(File arquivo) aoChegar;

  final ValueNotifier<EstadoVigia> estado = ValueNotifier(const EstadoVigia());

  StreamSubscription<FileSystemEvent>? _sub;
  final Map<String, Timer> _debounce = {};

  static const Duration _espera = Duration(seconds: 2);

  Future<String> caminhoPadrao() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.joinAll([docs.path, ...subpastaPadrao.split(RegExp(r'[\\/]'))]);
  }

  Future<String> caminhoAtual() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(chavePreferencia) ?? await caminhoPadrao();
  }

  Future<void> trocarPasta(String caminho) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(chavePreferencia, caminho);
    await iniciar();
  }

  /// Começa (ou recomeça) a vigiar e processa o que já estava na pasta e
  /// ainda não foi importado (a deduplicação por hash cuida do resto).
  Future<void> iniciar() async {
    await parar();
    String caminho = '';
    try {
      caminho = await caminhoAtual();
      final dir = Directory(caminho);
      if (!await dir.exists()) await dir.create(recursive: true);
      _sub = dir
          .watch(events: FileSystemEvent.create | FileSystemEvent.modify | FileSystemEvent.move)
          .listen(
            (e) => _agendar(e is FileSystemMoveEvent ? (e.destination ?? e.path) : e.path),
            onError: (Object erro) => estado.value = EstadoVigia(
              caminho: caminho,
              erro: 'Parou de vigiar: $erro',
            ),
          );
      estado.value = EstadoVigia(caminho: caminho, ativo: true);
      await for (final f in dir.list()) {
        if (f is File && aceita(f.path)) await _entregar(f);
      }
    } catch (e) {
      estado.value = EstadoVigia(caminho: caminho, erro: 'Pasta inválida: $e');
    }
  }

  Future<void> parar() async {
    await _sub?.cancel();
    _sub = null;
    for (final t in _debounce.values) {
      t.cancel();
    }
    _debounce.clear();
    estado.value = EstadoVigia(caminho: estado.value.caminho);
  }

  bool aceita(String caminho) {
    final nome = p.basename(caminho);
    if (nome.startsWith('~\$') || nome.startsWith('.')) return false;
    final ext = p.extension(nome).toLowerCase().replaceFirst('.', '');
    if (ext == 'tmp' || ext == 'crdownload' || ext == 'part') return false;
    return extensoes.contains(ext);
  }

  /// Debounce de 2 s por arquivo: o software ainda pode estar escrevendo.
  void _agendar(String caminho) {
    if (!aceita(caminho)) return;
    _debounce[caminho]?.cancel();
    _debounce[caminho] = Timer(_espera, () {
      _debounce.remove(caminho);
      _entregar(File(caminho));
    });
  }

  Future<void> _entregar(File arquivo) async {
    try {
      if (!await tamanhoEstavel(arquivo)) return;
      await aoChegar(arquivo);
    } catch (e) {
      debugPrint('Falha ao importar ${arquivo.path}: $e');
    }
  }

  /// Espera o tamanho parar de mudar (até ~10 s).
  static Future<bool> tamanhoEstavel(File arquivo) async {
    var anterior = -1;
    for (var i = 0; i < 14; i++) {
      if (!await arquivo.exists()) return false;
      final agora = await arquivo.length();
      if (agora > 0 && agora == anterior) return true;
      anterior = agora;
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    return false;
  }
}
