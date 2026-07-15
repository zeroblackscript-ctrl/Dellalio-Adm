import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Paleta de cores únicas para os usuários (15 cores bem distintas)
const List<Color> _userColorPalette = [
  Color(0xFFE53935), // vermelho
  Color(0xFF1E88E5), // azul
  Color(0xFF43A047), // verde
  Color(0xFFFB8C00), // laranja
  Color(0xFF8E24AA), // roxo
  Color(0xFF00ACC1), // ciano
  Color(0xFFD81B60), // rosa
  Color(0xFF3949AB), // azul escuro
  Color(0xFF6D4C41), // marrom
  Color(0xFF00897B), // verde escuro
  Color(0xFFF4511E), // laranja escuro
  Color(0xFF5E35B1), // roxo escuro
  Color(0xFF039BE5), // azul claro
  Color(0xFF689F38), // verde lima
  Color(0xFFC0CA33), // amarelo esverdeado
];

/// Gera uma cor consistente para um usuário baseado no seu ID
Color getUserColor(String userId) {
  final hash = userId.hashCode.abs();
  return _userColorPalette[hash % _userColorPalette.length];
}

/// Converte Color para string hex #RRGGBB
String colorToHex(Color c) {
  final r = (c.r * 255).round().clamp(0, 255);
  final g = (c.g * 255).round().clamp(0, 255);
  final b = (c.b * 255).round().clamp(0, 255);
  return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
}

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _displayMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _displayMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth =
        DateTime(_displayMonth.year, _displayMonth.month, 1);
    final daysInMonth =
        DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showMonthPicker(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('MMMM yyyy', 'pt_BR')
                    .format(_displayMonth)
                    .toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Colors.white),
            ],
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 98, 80, 63),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => setState(() {
              _displayMonth =
                  DateTime(_displayMonth.year, _displayMonth.month - 1);
            }),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () => setState(() {
              _displayMonth =
                  DateTime(_displayMonth.year, _displayMonth.month + 1);
            }),
          ),
        ],
      ),
      // Layout dividido: calendário à esquerda, compromissos à direita
      body: Row(
        children: [
          // Lado esquerdo: Calendário
          SizedBox(
            width: 420,
            child: Column(
              children: [
                // Cabeçalho dos dias da semana
                _buildWeekHeader(),

                // Grid do calendário
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 1,
                      mainAxisSpacing: 1,
                    ),
                    itemCount: daysInMonth + startWeekday,
                    itemBuilder: (context, index) {
                      if (index < startWeekday) {
                        return const SizedBox.shrink();
                      }
                      final day = DateTime(_displayMonth.year,
                          _displayMonth.month, index - startWeekday + 1);
                      return _buildDayCell(day);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Divisor vertical
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE0E0E0)),

          // Lado direito: Detalhes do dia selecionado
          Expanded(
            child: _buildDayDetails(_selectedDay),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 98, 80, 63),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
        onPressed: () => _showEventDialog(_selectedDay, null),
      ),
    );
  }

  Widget _buildWeekHeader() {
    final dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: dias
            .map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: d == 'Dom' || d == 'Sáb'
                            ? Colors.red[300]
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDayCell(DateTime day) {
    final now = DateTime.now();
    final bool isToday = day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
    final bool isSelected = day == _selectedDay;
    final bool isWeekend =
        day.weekday == DateTime.sunday || day.weekday == DateTime.saturday;

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = day),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromARGB(255, 98, 80, 63).withValues(alpha: 0.12)
              : isToday
                  ? Colors.amber.withValues(alpha: 0.08)
                  : Colors.white,
          border: Border(
            bottom: BorderSide(
                color: isSelected
                    ? const Color.fromARGB(255, 98, 80, 63)
                        .withValues(alpha: 0.3)
                    : Colors.grey.shade200,
                width: isSelected ? 2 : 0.5),
            right: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('agenda')
              .where('date',
                  isGreaterThanOrEqualTo:
                      Timestamp.fromDate(DateTime(day.year, day.month, day.day)))
              .where('date',
                  isLessThan: Timestamp.fromDate(
                      DateTime(day.year, day.month, day.day + 1)))
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Número do dia
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4),
                  child: Container(
                    width: isToday ? 20 : null,
                    height: isToday ? 20 : null,
                    alignment: Alignment.center,
                    decoration: isToday
                        ? BoxDecoration(
                            color: const Color.fromARGB(255, 98, 80, 63),
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: Text(
                      "${day.day}",
                      style: TextStyle(
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                        color: isToday
                            ? Colors.white
                            : isWeekend
                                ? Colors.red[300]
                                : Colors.black87,
                      ),
                    ),
                  ),
                ),
                // Barras de compromissos (indicadores)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 1, 2, 0),
                    child: SingleChildScrollView(
                      child: Column(
                        children: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final color = Color(
                            int.tryParse(data['userColor']
                                        ?.toString()
                                        .replaceFirst('#', '0xff') ??
                                    '0xffE53935') ??
                                0xffE53935,
                          );
                          final int imp = data['importancia'] ?? 0;
                          final String name = (data['userName'] ?? '?')
                              .toString()
                              .toUpperCase();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 0.5),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(2),
                              border: imp >= 3
                                  ? const Border(
                                      left: BorderSide(
                                          color: Colors.red, width: 2))
                                  : imp >= 2
                                      ? const Border(
                                          left: BorderSide(
                                              color: Colors.orange, width: 2))
                                      : null,
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                                color: imp >= 3
                                    ? const Color(0xFFB71C1C)
                                    : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ======================================================
  // PAINEL DIREITO: detalhes do dia selecionado
  // ======================================================
  Widget _buildDayDetails(DateTime day) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('agenda')
          .where('date',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(DateTime(day.year, day.month, day.day)))
          .where('date',
              isLessThan: Timestamp.fromDate(
                  DateTime(day.year, day.month, day.day + 1)))
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy, size: 56, color: Colors.grey[350]),
                const SizedBox(height: 10),
                Text(
                  'Nenhum compromisso',
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat("dd 'de' MMMM", 'pt_BR').format(day),
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          );
        }

        final sorted = List.from(docs)
          ..sort((a, b) {
            final da = a.data() as Map<String, dynamic>;
            final db = b.data() as Map<String, dynamic>;
            final ta = da['time'] ?? '';
            final tb = db['time'] ?? '';
            if (ta.isNotEmpty && tb.isNotEmpty) return ta.compareTo(tb);
            final int ia = da['importancia'] ?? 0;
            final int ib = db['importancia'] ?? 0;
            return ib.compareTo(ia);
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do dia
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 98, 80, 63)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        "${day.day}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color.fromARGB(255, 98, 80, 63),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat("EEEE, MMMM", 'pt_BR').format(day),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color.fromARGB(255, 98, 80, 63),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${sorted.length} compromisso${sorted.length != 1 ? 's' : ''}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),

            // Lista de compromissos
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final data =
                      sorted[index].data() as Map<String, dynamic>;
                  final doc = sorted[index] as QueryDocumentSnapshot;
                  final int imp = data['importancia'] ?? 0;
                  final String time = data['time'] ?? '';
                  final String text = data['text'] ?? '';
                  final String info = data['info'] ?? '';
                  final String userName = data['userName'] ?? '?';
                  final Color userColor = Color(
                    int.tryParse(data['userColor']
                                ?.toString()
                                .replaceFirst('#', '0xff') ??
                            '0xffE53935') ??
                        0xffE53935,
                  );

                  final Color impColor = imp >= 3
                      ? Colors.red
                      : imp >= 2
                          ? Colors.orange
                          : const Color.fromARGB(255, 98, 80, 63);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showEventDialog(day, doc),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border(
                            left: BorderSide(color: impColor, width: 4),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Linha 1: Horário + badge + avatar
                              Row(
                                children: [
                                  if (time.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: impColor
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        time,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: impColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  _badge(impColor,
                                      imp >= 3
                                          ? 'Alta'
                                          : imp >= 2
                                              ? 'Média'
                                              : 'Normal',
                                      imp),
                                  const Spacer(),
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: userColor,
                                    child: Text(
                                      userName.isNotEmpty
                                          ? userName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Título
                              Text(
                                text.isNotEmpty ? text : 'Sem título',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                              // Info inline
                              if (info.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    info,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _badge(Color color, String label, int imp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // DIÁLOGO DE CRIAÇÃO / EDIÇÃO
  // ======================================================
  void _showEventDialog(DateTime day, DocumentSnapshot? doc) async {
    final user = FirebaseAuth.instance.currentUser!;
    final isEditing = doc != null;
    final data = isEditing ? doc.data() as Map<String, dynamic> : null;
    final isOwner = !isEditing || data?['userId'] == user.uid;

    final descCtrl = TextEditingController(text: data?['text'] ?? '');
    final infoCtrl = TextEditingController(text: data?['info'] ?? '');
    final timeCtrl = TextEditingController(text: data?['time'] ?? '');
    int imp = data?['importancia'] ?? 0;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 98, 80, 63)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "${day.day}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color.fromARGB(255, 98, 80, 63),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat("EEEE, dd 'de' MMMM", 'pt_BR')
                                  .format(day),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color.fromARGB(255, 98, 80, 63),
                              ),
                            ),
                            Text(
                              DateFormat("yyyy", 'pt_BR').format(day),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Horário
                  if (isOwner) ...[
                    _dialogLabel('HORÁRIO'),
                    const SizedBox(height: 6),
                    _dialogField(
                      controller: timeCtrl,
                      hint: 'Toque para selecionar o horário',
                      icon: Icons.access_time,
                      readOnly: true,
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: context, initialTime: TimeOfDay.now());
                        if (picked != null) {
                          timeCtrl.text =
                              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ] else if (timeCtrl.text.isNotEmpty) ...[
                    Row(children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      Text(timeCtrl.text,
                          style: const TextStyle(fontSize: 14)),
                    ]),
                    const SizedBox(height: 16),
                  ],

                  // Importância
                  _dialogLabel('NÍVEL DE IMPORTÂNCIA'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _importanceChip('Normal', 0, imp, isOwner,
                          (v) => setDlg(() => imp = v),
                          const Color.fromARGB(255, 98, 80, 63)),
                      const SizedBox(width: 8),
                      _importanceChip('Média', 2, imp, isOwner,
                          (v) => setDlg(() => imp = v), Colors.orange),
                      const SizedBox(width: 8),
                      _importanceChip('Alta', 3, imp, isOwner,
                          (v) => setDlg(() => imp = v), Colors.red),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // O que será feito
                  _dialogLabel('O QUE SERÁ FEITO'),
                  const SizedBox(height: 6),
                  _dialogField(
                    controller: descCtrl,
                    hint: 'Título ou tarefa principal...',
                    enabled: isOwner,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Info adicional
                  _dialogLabel('INFORMAÇÕES ADICIONAIS'),
                  const SizedBox(height: 6),
                  _dialogField(
                    controller: infoCtrl,
                    hint: 'Medidas, observações ou notas...',
                    enabled: isOwner,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Botões
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isEditing && isOwner)
                        TextButton(
                          onPressed: () {
                            doc.reference.delete();
                            Navigator.pop(context);
                          },
                          child: const Text('EXCLUIR',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ),
                      if (isOwner) ...[
                        const Spacer(),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 98, 80, 63),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(
                              isEditing ? Icons.save : Icons.add,
                              size: 20),
                          label: Text(
                            isEditing ? 'SALVAR' : 'ADICIONAR',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          onPressed: () async {
                            if (descCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'O campo "O que será feito" é obrigatório'),
                                    backgroundColor: Colors.red),
                              );
                              return;
                            }

                            // Busca dados do usuário
                            final userRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid);
                            final userDoc = await userRef.get();
                            final userData = userDoc.data();

                            // Gera/obtém cor do usuário
                            String userColor;
                            if (userData != null &&
                                userData['userColor'] != null &&
                                userData['userColor']
                                    .toString()
                                    .isNotEmpty) {
                              userColor = userData['userColor'].toString();
                            } else {
                              // Gera cor automática e salva no documento do usuário
                              final color = getUserColor(user.uid);
                              userColor = colorToHex(color);
                              await userRef.set({
                                'userColor': userColor,
                              }, SetOptions(merge: true));
                            }

                            final nota = {
                              'userId': user.uid,
                              'userName': userData?['nome'] ?? 'Usuário',
                              'userColor': userColor,
                              'text': descCtrl.text.trim(),
                              'info': infoCtrl.text.trim(),
                              'time': timeCtrl.text.trim(),
                              'importancia': imp,
                              'date': Timestamp.fromDate(day),
                            };

                            if (!isEditing) {
                              await FirebaseFirestore.instance
                                  .collection('agenda')
                                  .add(nota);
                            } else {
                              await doc.reference.update(nota);
                            }
                            if (!mounted) return;
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ],
                  ),

                  // Quem criou
                  if (isEditing) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Color(
                              int.tryParse(data?['userColor']
                                          ?.toString()
                                          .replaceFirst('#', '0xff') ??
                                      '0xffE53935') ??
                                  0xffE53935,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Criado por ${data?['userName'] ?? 'Desconhecido'}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 0.8));
  }

  Widget _dialogField({
    required TextEditingController controller,
    String hint = '',
    IconData? icon,
    bool enabled = true,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        filled: true,
        fillColor: enabled ? Colors.grey[100] : Colors.grey[200],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: Colors.grey[500])
            : null,
      ),
    );
  }

  Widget _importanceChip(String label, int val, int cur, bool enabled,
      Function(int) onSel, Color color) {
    final sel = cur == val;
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? () => onSel(val) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.15) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag,
                  size: 20, color: sel ? color : Colors.grey[400]),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                  color: sel ? color : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMonthPicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _displayMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _displayMonth = picked);
  }
}