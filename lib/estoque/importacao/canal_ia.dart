import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

/// Modelo Gemini usado nas chamadas (Flash mais recente). Fica aqui pra
/// trocar num lugar só; a Cloud Function aceita qualquer `gemini-*`.
const String kModeloIA = 'gemini-3.5-flash';

/// Região das Cloud Functions de IA (`functions/index.js`).
const String kRegiaoFunctions = 'southamerica-east1';

class IAIndisponivel implements Exception {
  final String motivo;
  const IAIndisponivel(this.motivo);
  @override
  String toString() => 'IA indisponível: $motivo';
}

/// Canal único com a IA (Gemini via Firebase/Vertex), passando por Cloud
/// Functions callable. O `firebase_ai` e o `cloud_functions` não rodam no
/// Windows, então a chamada usa o protocolo callable direto em HTTPS, com o
/// token do usuário logado. Nenhuma chave de API fica no app.
class CanalIA {
  const CanalIA();

  static CanalIA padrao = const CanalIA();

  Future<Object?> chamar(String funcao, Map<String, dynamic> dados) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const IAIndisponivel('sem usuário logado');
    final projeto = Firebase.app().options.projectId;
    final url = Uri.parse(
      'https://$kRegiaoFunctions-$projeto.cloudfunctions.net/$funcao',
    );
    final token = await user.getIdToken();
    final resp = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'data': {...dados, 'modelo': kModeloIA}}),
        )
        .timeout(const Duration(seconds: 150));
    final corpo = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if (resp.statusCode != 200 || corpo.containsKey('error')) {
      final erro = corpo['error'];
      throw IAIndisponivel(
        erro is Map ? '${erro['status']}: ${erro['message']}' : 'HTTP ${resp.statusCode}',
      );
    }
    return corpo['result'];
  }

  /// Lista de compras/corte em PDF (inclusive escaneado) ou imagem →
  /// `{clienteNome, projetoNome, itens: [...]}` no schema de `ListaLida`.
  Future<Map<String, dynamic>> lerLista(Uint8List bytes, String mimeType) async =>
      Map<String, dynamic>.from(
        await chamar('lerListaComIA', {
          'arquivoBase64': base64Encode(bytes),
          'mimeType': mimeType,
        }) as Map,
      );

  /// DANFE em PDF ou foto → chave, emitente, número, data e itens.
  Future<Map<String, dynamic>> lerNota(Uint8List bytes, String mimeType) async =>
      Map<String, dynamic>.from(
        await chamar('lerNotaComIA', {
          'arquivoBase64': base64Encode(bytes),
          'mimeType': mimeType,
        }) as Map,
      );

  /// Planilha sem cabeçalho reconhecível → `{linhaCabecalho, colunas:
  /// {descricao: 0, quantidade: 3, ...}}`.
  Future<Map<String, dynamic>?> mapearColunas(List<List<String>> linhas) async {
    final r = await chamar('mapearColunasComIA', {'linhas': linhas});
    return r is Map ? Map<String, dynamic>.from(r) : null;
  }

  /// Desempate do casamento, uma chamada por lista:
  /// entrada `[{indice, descricao, candidatos: [{materialId, nome}]}]`,
  /// saída `[{indice, materialId|null, confianca}]`.
  Future<List<Map<String, dynamic>>> desempatar(
    List<Map<String, dynamic>> itens,
  ) async {
    final r = await chamar('desempatarComIA', {'itens': itens});
    final lista = r is Map ? r['respostas'] : r;
    return lista is List
        ? lista.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : const [];
  }
}
