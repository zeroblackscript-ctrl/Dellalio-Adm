import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../importacao/vigia_pasta.dart';

/// Arquivo de nota vindo de qualquer fonte.
class ArquivoNota {
  final String nome;
  final Uint8List bytes;
  final String? caminho;
  const ArquivoNota({required this.nome, required this.bytes, this.caminho});
}

/// De onde chegam as notas. Hoje: pasta vigiada. Fase 2: uma `FonteSefaz`
/// (Distribuição DF-e com o certificado A1) implementa esta mesma
/// interface e entra sem mudar o importador.
abstract class FonteNotas {
  Stream<ArquivoNota> get arquivos;
  Future<void> iniciar();
  Future<void> parar();
}

/// Pasta `Documentos\Dellalio\Notas`, com o mesmo vigia das listas.
class FontePasta implements FonteNotas {
  FontePasta() {
    vigia = VigiaPasta(
      chavePreferencia: 'pasta_notas',
      subpastaPadrao: r'Dellalio\Notas',
      extensoes: const {'xml', 'pdf'},
      aoChegar: (File f) async => _saida.add(
        ArquivoNota(nome: p.basename(f.path), bytes: await f.readAsBytes(), caminho: f.path),
      ),
    );
  }

  late final VigiaPasta vigia;
  final StreamController<ArquivoNota> _saida = StreamController.broadcast();

  @override
  Stream<ArquivoNota> get arquivos => _saida.stream;

  @override
  Future<void> iniciar() => vigia.iniciar();

  @override
  Future<void> parar() => vigia.parar();
}
