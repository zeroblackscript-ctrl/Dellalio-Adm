import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Helpers para escolher e subir imagens/vídeos pro Firebase Storage —
/// mesmo fluxo já usado em `edit_item_screen.dart`, centralizado aqui pra
/// não repetir em cada editor do painel "App Clientes".

/// Abre o seletor de arquivos e retorna os bytes da imagem escolhida (ou
/// `null` se o usuário cancelar).
Future<Uint8List?> pickImageBytes() async {
  final result = await FilePicker.pickFiles(
    type: FileType.image,
    withData: true,
  );
  return result?.files.first.bytes;
}

/// Abre o seletor de arquivos e retorna os bytes do vídeo escolhido (ou
/// `null` se o usuário cancelar).
Future<Uint8List?> pickVideoBytes() async {
  final result = await FilePicker.pickFiles(
    type: FileType.video,
    withData: true,
  );
  return result?.files.first.bytes;
}

/// Sobe [bytes] para `site_content/<folder>/<timestamp>.<ext>` no Firebase
/// Storage e retorna a URL pública de download.
Future<String> uploadSiteContentMedia(
  Uint8List bytes,
  String folder, {
  String ext = 'jpg',
}) async {
  final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
  final ref = FirebaseStorage.instance.ref('site_content/$folder/$fileName');
  await ref.putData(bytes);
  return ref.getDownloadURL();
}
