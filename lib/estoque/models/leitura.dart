import 'package:cloud_firestore/cloud_firestore.dart';

/// Leitura tolerante de campos do Firestore: documento antigo ou incompleto
/// nunca derruba a tela.
double lerNum(Object? v, [double padrao = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? padrao;
  return padrao;
}

double? lerNumOuNulo(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}

String? lerTexto(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? lerData(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

List<String> lerListaTexto(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

List<Map<String, dynamic>> lerListaMapas(Object? v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

Map<String, double> lerMapaNum(Object? v) => v is Map
    ? v.map((k, val) => MapEntry(k.toString(), lerNum(val)))
    : const {};

Map<String, String> lerMapaTexto(Object? v) => v is Map
    ? v.map((k, val) => MapEntry(k.toString(), val.toString()))
    : const {};

/// Remove chaves nulas antes de gravar, pra não poluir o documento.
Map<String, dynamic> semNulos(Map<String, dynamic> m) =>
    Map.of(m)..removeWhere((_, v) => v == null);
