import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';

/// Paleta harmonizada de cores por usuário — reaproveita os tons já usados
/// no resto do painel em vez de cores cruas do Material.
final List<Color> _userColorPalette = [
  dellalioGold,
  panelRust,
  navyAccent,
  panelSage,
  statusConferencia,
  statusMontagem,
];

Color getUserColor(String userId) {
  final hash = userId.hashCode.abs();
  return _userColorPalette[hash % _userColorPalette.length];
}

String colorToHex(Color c) {
  final r = (c.r * 255).round().clamp(0, 255);
  final g = (c.g * 255).round().clamp(0, 255);
  final b = (c.b * 255).round().clamp(0, 255);
  return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
}

Color _colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return panelRust;
  final parsed = int.tryParse(hex.replaceFirst('#', '0xff'));
  return parsed != null ? Color(parsed) : panelRust;
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
    final firstDayOfMonth = DateTime(
      _displayMonth.year,
      _displayMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _displayMonth.year,
      _displayMonth.month + 1,
      0,
    ).day;
    final startWeekday = firstDayOfMonth.weekday % 7;

    return Scaffold(
      backgroundColor: inkPageBg,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(34, 26, 34, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showMonthPicker(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat(
                              'MMMM yyyy',
                              'pt_BR',
                            ).format(_displayMonth),
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontWeight: FontWeight.w500,
                              fontSize: 22,
                              color: panelIvory,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 20,
                            color: panelSlate,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _ArrowButton(
                      icon: Icons.chevron_left,
                      onTap: () => setState(() {
                        _displayMonth = DateTime(
                          _displayMonth.year,
                          _displayMonth.month - 1,
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    _ArrowButton(
                      icon: Icons.chevron_right,
                      onTap: () => setState(() {
                        _displayMonth = DateTime(
                          _displayMonth.year,
                          _displayMonth.month + 1,
                        );
                      }),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 420,
                      child: Column(
                        children: [
                          _buildWeekHeader(),
                          Expanded(
                            child: GridView.builder(
                              padding: EdgeInsets.zero,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    childAspectRatio: 1.0,
                                  ),
                              itemCount: daysInMonth + startWeekday,
                              itemBuilder: (context, index) {
                                if (index < startWeekday) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: hairline),
                                        bottom: BorderSide(color: hairline),
                                      ),
                                    ),
                                  );
                                }
                                final day = DateTime(
                                  _displayMonth.year,
                                  _displayMonth.month,
                                  index - startWeekday + 1,
                                );
                                return _buildDayCell(day);
                              },
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 80.ms),
                    Container(width: 1, color: hairline),
                    Expanded(
                      child: _buildDayDetails(
                        _selectedDay,
                      ).animate().fadeIn(duration: 400.ms, delay: 140.ms),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 36,
            bottom: 32,
            child: _Fab(onPressed: () => _showEventDialog(_selectedDay, null)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekHeader() {
    final dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Row(
        children: dias
            .map(
              (d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10.5,
                      letterSpacing: 0.4,
                      color: (d == 'Dom' || d == 'Sáb')
                          ? const Color(0xFFE39A85)
                          : panelSlate,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDayCell(DateTime day) {
    final now = DateTime.now();
    final bool isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final bool isSelected = day == _selectedDay;
    final bool isWeekend =
        day.weekday == DateTime.sunday || day.weekday == DateTime.saturday;

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = day),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? dellalioGold.withValues(alpha: 0.07)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: hairline),
            right: BorderSide(color: hairline),
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('agenda')
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime(day.year, day.month, day.day),
                ),
              )
              .where(
                'date',
                isLessThan: Timestamp.fromDate(
                  DateTime(day.year, day.month, day.day + 1),
                ),
              )
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            return Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isToday
                      ? Container(
                          width: 19,
                          height: 19,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: dellalioGold,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "${day.day}",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                              color: inkPageBg,
                            ),
                          ),
                        )
                      : Text(
                          "${day.day}",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 11.5,
                            color: isWeekend
                                ? const Color(0xFFE39A85)
                                : panelIvory,
                          ),
                        ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final color = _colorFromHex(
                            data['userColor']?.toString(),
                          );
                          final String name = (data['userName'] ?? '?')
                              .toString()
                              .toUpperCase();
                          return Container(
                            margin: const EdgeInsets.only(top: 3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDayDetails(DateTime day) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('agenda')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime(day.year, day.month, day.day),
            ),
          )
          .where(
            'date',
            isLessThan: Timestamp.fromDate(
              DateTime(day.year, day.month, day.day + 1),
            ),
          )
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: hairline)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: dellalioGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        "${day.day}",
                        style: TextStyle(
                          fontFamily: 'Fraunces',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: dellalioGoldSoft,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat("EEEE, MMMM", 'pt_BR').format(day),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: panelIvory,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: hairline),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${docs.length} compromisso${docs.length != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 11, color: panelSlate),
                    ),
                  ),
                ],
              ),
            ),
            if (docs.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_busy_outlined,
                        size: 48,
                        color: panelSlateDim,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Nenhum compromisso',
                        style: TextStyle(color: panelSlate, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat("dd 'de' MMMM", 'pt_BR').format(day),
                        style: TextStyle(color: panelSlateDim, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Builder(
                  builder: (context) {
                    final sorted = List.from(docs)
                      ..sort((a, b) {
                        final da = a.data() as Map<String, dynamic>;
                        final db = b.data() as Map<String, dynamic>;
                        final ta = da['time'] ?? '';
                        final tb = db['time'] ?? '';
                        if (ta.isNotEmpty && tb.isNotEmpty)
                          return ta.compareTo(tb);
                        final int ia = da['importancia'] ?? 0;
                        final int ib = db['importancia'] ?? 0;
                        return ib.compareTo(ia);
                      });

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
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
                        final Color userColor = _colorFromHex(
                          data['userColor']?.toString(),
                        );
                        final Color impColor = imp >= 3
                            ? panelRust
                            : imp >= 2
                            ? dellalioGold
                            : navyAccent;

                        return _EventCard(
                          time: time,
                          title: text.isNotEmpty ? text : 'Sem título',
                          info: info,
                          impColor: impColor,
                          impLabel: imp >= 3
                              ? 'ALTA'
                              : imp >= 2
                              ? 'MÉDIA'
                              : 'NORMAL',
                          userName: userName,
                          userColor: userColor,
                          delayIndex: index % 12,
                          onTap: () => _showEventDialog(day, doc),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

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
          backgroundColor: inkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: dellalioGold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "${day.day}",
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: dellalioGoldSoft,
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
                              DateFormat(
                                "EEEE, dd 'de' MMMM",
                                'pt_BR',
                              ).format(day),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                                color: panelIvory,
                              ),
                            ),
                            Text(
                              DateFormat("yyyy", 'pt_BR').format(day),
                              style: TextStyle(fontSize: 12, color: panelSlate),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(height: 1, color: hairline),
                  const SizedBox(height: 18),
                  if (isOwner) ...[
                    _dialogLabel('Horário'),
                    const SizedBox(height: 6),
                    _dialogField(
                      controller: timeCtrl,
                      hint: 'Toque para selecionar o horário',
                      icon: Icons.access_time,
                      readOnly: true,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          timeCtrl.text =
                              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ] else if (timeCtrl.text.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: panelSlate),
                        const SizedBox(width: 4),
                        Text(
                          timeCtrl.text,
                          style: TextStyle(fontSize: 14, color: panelIvory),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  _dialogLabel('Nível de importância'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _importanceChip(
                        'Normal',
                        0,
                        imp,
                        isOwner,
                        (v) => setDlg(() => imp = v),
                        navyAccent,
                      ),
                      const SizedBox(width: 8),
                      _importanceChip(
                        'Média',
                        2,
                        imp,
                        isOwner,
                        (v) => setDlg(() => imp = v),
                        dellalioGold,
                      ),
                      const SizedBox(width: 8),
                      _importanceChip(
                        'Alta',
                        3,
                        imp,
                        isOwner,
                        (v) => setDlg(() => imp = v),
                        panelRust,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _dialogLabel('O que será feito'),
                  const SizedBox(height: 6),
                  _dialogField(
                    controller: descCtrl,
                    hint: 'Título ou tarefa principal...',
                    enabled: isOwner,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  _dialogLabel('Informações adicionais'),
                  const SizedBox(height: 6),
                  _dialogField(
                    controller: infoCtrl,
                    hint: 'Medidas, observações ou notas...',
                    enabled: isOwner,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isEditing && isOwner)
                        TextButton(
                          onPressed: () {
                            doc.reference.delete();
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Excluir',
                            style: TextStyle(
                              color: panelRust,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (isOwner) ...[
                        const Spacer(),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dellalioGold,
                            foregroundColor: inkPageBg,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(
                            isEditing ? Icons.save_outlined : Icons.add,
                            size: 20,
                          ),
                          label: Text(
                            isEditing ? 'Salvar' : 'Adicionar',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          onPressed: () async {
                            if (descCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'O campo "O que será feito" é obrigatório',
                                  ),
                                  backgroundColor: panelRust,
                                ),
                              );
                              return;
                            }
                            final userRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid);
                            final userDoc = await userRef.get();
                            final userData = userDoc.data();
                            String userColor;
                            if (userData != null &&
                                userData['userColor'] != null &&
                                userData['userColor'].toString().isNotEmpty) {
                              userColor = userData['userColor'].toString();
                            } else {
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
                  if (isEditing) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: inkSurfaceHover,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: _colorFromHex(
                              data?['userColor']?.toString(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Criado por ${data?['userName'] ?? 'desconhecido'}',
                            style: TextStyle(fontSize: 12, color: panelSlate),
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
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: panelSlate,
        letterSpacing: 0.6,
      ),
    );
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
      style: TextStyle(color: panelIvory),
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: panelSlateDim, fontSize: 14),
        filled: true,
        fillColor: enabled ? inkSurfaceHover : inkPageBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: panelSlate)
            : null,
      ),
    );
  }

  Widget _importanceChip(
    String label,
    int val,
    int cur,
    bool enabled,
    Function(int) onSel,
    Color color,
  ) {
    final sel = cur == val;
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? () => onSel(val) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.12) : inkSurfaceHover,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag_outlined,
                size: 18,
                color: sel ? color : panelSlateDim,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  color: sel ? color : panelSlate,
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

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: hairline),
        ),
        child: Icon(icon, size: 17, color: panelSlate),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  final VoidCallback onPressed;
  const _Fab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dellalioGold,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(Icons.add, color: inkPageBg, size: 24),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final String time;
  final String title;
  final String info;
  final Color impColor;
  final String impLabel;
  final String userName;
  final Color userColor;
  final int delayIndex;
  final VoidCallback onTap;

  const _EventCard({
    required this.time,
    required this.title,
    required this.info,
    required this.impColor,
    required this.impLabel,
    required this.userName,
    required this.userColor,
    required this.delayIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child:
            Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: inkSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(color: impColor, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (time.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: impColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                time,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                  color: impColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: impColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flag, size: 11, color: impColor),
                                const SizedBox(width: 4),
                                Text(
                                  impLabel,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: impColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: userColor,
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: panelIvory,
                        ),
                      ),
                      if (info.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: inkSurfaceHover,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            info,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: panelSlate,
                              height: 1.4,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
                .animate(delay: (50 * delayIndex).ms)
                .fadeIn(duration: 380.ms, curve: Curves.easeOut)
                .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
      ),
    );
  }
}
