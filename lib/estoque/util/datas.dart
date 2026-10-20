import 'package:intl/intl.dart';

/// Datas em pt-BR, no jeito curto das telas.
final DateFormat _hora = DateFormat('HH:mm', 'pt_BR');
final DateFormat _diaMes = DateFormat("d MMM", 'pt_BR');
final DateFormat _completa = DateFormat("dd/MM/yyyy HH:mm", 'pt_BR');
final DateFormat _extenso = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');

String _semPonto(String s) => s.replaceAll('.', '');

/// "hoje 08:12", "ontem", "17 out", "17 out 2025".
String fmtQuando(DateTime? d, {bool comHora = true, DateTime? agora}) {
  if (d == null) return 'agora';
  final hoje = agora ?? DateTime.now();
  final dia = DateTime(d.year, d.month, d.day);
  final ref = DateTime(hoje.year, hoje.month, hoje.day);
  final diff = ref.difference(dia).inDays;
  if (diff == 0) return comHora ? 'hoje ${_hora.format(d)}' : 'hoje';
  if (diff == 1) return comHora ? 'ontem ${_hora.format(d)}' : 'ontem';
  final base = _semPonto(_diaMes.format(d));
  return d.year == hoje.year ? base : '$base ${d.year}';
}

/// "16 out 14:30" (histórico).
String fmtDiaHora(DateTime? d) {
  if (d == null) return 'agora';
  final hoje = DateTime.now();
  if (d.year == hoje.year && d.month == hoje.month && d.day == hoje.day) {
    return 'hoje ${_hora.format(d)}';
  }
  return '${_semPonto(_diaMes.format(d))} ${_hora.format(d)}';
}

String fmtCompleta(DateTime? d) => d == null ? '' : _completa.format(d);

String fmtHora(DateTime? d) => d == null ? '' : _hora.format(d);

/// "Terça, 20 de outubro".
String fmtExtenso(DateTime d) {
  final s = _extenso.format(d).replaceFirst('-feira', '');
  return s[0].toUpperCase() + s.substring(1);
}

String saudacao([DateTime? agora]) {
  final h = (agora ?? DateTime.now()).hour;
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
}
