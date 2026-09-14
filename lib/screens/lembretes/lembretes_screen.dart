import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  static const Map<String, Color> _colorMap = {
    'red': panelRust,
    'yellow': dellalioGold,
    'green': panelSage,
  };

  Color _accentFor(String? id) => _colorMap[id] ?? dellalioGold;

  static const Map<String, String> _levelLabels = {
    'red': 'Alta',
    'yellow': 'Média',
    'green': 'Baixa',
  };

  String _levelLabelFor(String? id) => _levelLabels[id] ?? 'Média';

  void _showAddReminderDialog({DocumentSnapshot? existingDoc}) {
    final bool isEditing = existingDoc != null;
    final Map<String, dynamic>? existingData = isEditing
        ? existingDoc.data() as Map<String, dynamic>?
        : null;

    final TextEditingController titleCtrl = TextEditingController(
      text: existingData?['title']?.toString() ?? '',
    );
    final TextEditingController contentCtrl = TextEditingController(
      text: existingData?['content']?.toString() ?? '',
    );
    DateTime selectedDate = isEditing && existingData?['dateTime'] != null
        ? (existingData!['dateTime'] as Timestamp).toDate()
        : DateTime.now();
    TimeOfDay selectedTime = isEditing && existingData?['dateTime'] != null
        ? TimeOfDay.fromDateTime(
            (existingData!['dateTime'] as Timestamp).toDate(),
          )
        : TimeOfDay.now();
    String selectedColor = existingData?['color']?.toString() ?? 'yellow';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: inkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            title: Text(
              isEditing ? "Editar lembrete" : "Novo lembrete",
              style: TextStyle(
                color: panelIvory,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DialogField(controller: titleCtrl, label: "Título"),
                  const SizedBox(height: 10),
                  _DialogField(
                    controller: contentCtrl,
                    label: "Assunto",
                    maxLines: 3,
                  ),
                  const SizedBox(height: 15),
                  _DialogRow(
                    label:
                        "Data: ${DateFormat('dd/MM/yyyy').format(selectedDate)}",
                    icon: Icons.calendar_today_outlined,
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null)
                        setDialogState(() => selectedDate = picked);
                    },
                  ),
                  _DialogRow(
                    label: "Hora: ${selectedTime.format(context)}",
                    icon: Icons.access_time,
                    onTap: () async {
                      TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null)
                        setDialogState(() => selectedTime = picked);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _colorOption(
                        'red',
                        panelRust,
                        selectedColor,
                        (c) => setDialogState(() => selectedColor = c),
                      ),
                      _colorOption(
                        'yellow',
                        dellalioGold,
                        selectedColor,
                        (c) => setDialogState(() => selectedColor = c),
                      ),
                      _colorOption(
                        'green',
                        panelSage,
                        selectedColor,
                        (c) => setDialogState(() => selectedColor = c),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancelar", style: TextStyle(color: panelSlate)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: dellalioGold,
                  foregroundColor: inkPageBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  String userName = await _getUserName();
                  final DateTime finalDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );

                  final Map<String, dynamic> reminderData = {
                    'title': titleCtrl.text,
                    'content': contentCtrl.text,
                    'color': selectedColor,
                    'priority': selectedColor == 'red'
                        ? 1
                        : selectedColor == 'yellow'
                        ? 2
                        : 3,
                    'dateTime': Timestamp.fromDate(finalDateTime),
                  };

                  if (isEditing) {
                    await existingDoc.reference.update(reminderData);
                  } else {
                    reminderData['author'] = userName;
                    reminderData['createdAt'] = FieldValue.serverTimestamp();
                    await FirebaseFirestore.instance
                        .collection('reminders')
                        .add(reminderData);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(
                  isEditing ? "Salvar alterações" : "Salvar",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _colorOption(
    String id,
    Color color,
    String selected,
    Function(String) onTap,
  ) {
    final bool isSelected = selected == id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: () => onTap(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: isSelected ? panelIvory : Colors.transparent,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : null,
        ),
      ),
    );
  }

  Future<String> _getUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "Anônimo";
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        return data['nome'] ?? "Usuário";
      }
    } catch (e) {
      debugPrint("Erro ao buscar nome: $e");
    }
    return "Usuário";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(34, 30, 34, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      "Lembretes",
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontWeight: FontWeight.w500,
                        fontSize: 27,
                        color: dellalioTitle,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.05, end: 0),
                const SizedBox(height: 26),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reminders')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        "Erro: ${snapshot.error}",
                        style: TextStyle(color: panelRust),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: dellalioGold),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          "Nenhum lembrete por aqui ainda.",
                          style: TextStyle(color: panelSlate),
                        ),
                      );
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 240,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.68,
                          ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final DateTime dt = (data['dateTime'] as Timestamp)
                            .toDate();
                        final String colorId =
                            data['color']?.toString() ?? '';

                        return _ReminderCard(
                          title: (data['title'] ?? '').toString().toUpperCase(),
                          content: (data['content'] ?? '').toString(),
                          author: (data['author'] ?? '').toString(),
                          dateLabel: DateFormat('dd/MM HH:mm').format(dt),
                          accent: _accentFor(colorId),
                          levelLabel: _levelLabelFor(colorId),
                          delayIndex: index % 12,
                          onEdit: () =>
                              _showAddReminderDialog(existingDoc: doc),
                          onDelete: () => doc.reference.delete(),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            right: 36,
            bottom: 32,
            child: _Fab(onPressed: () => _showAddReminderDialog()),
          ),
        ],
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  const _DialogField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: panelIvory),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: panelSlate),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: dellalioGold),
        ),
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DialogRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: panelIvory, fontSize: 14)),
      trailing: Icon(icon, color: panelSlate, size: 18),
      onTap: onTap,
    );
  }
}

/// Botão flutuante dourado com um anel pulsando devagar por trás.
class _Fab extends StatelessWidget {
  final VoidCallback onPressed;
  const _Fab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child:
                Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: dellalioGold),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .custom(
                      duration: 2600.ms,
                      builder: (context, value, child) => Opacity(
                        opacity: (1 - value) * 0.5,
                        child: Transform.scale(
                          scale: 1 + value * 0.28,
                          child: child,
                        ),
                      ),
                    ),
          ),
          Container(
            width: 50,
            height: 50,
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
            child: Icon(Icons.add, color: inkPageBg, size: 22),
          ),
        ],
      ),
    );
  }
}

/// Card de lembrete — superfície neutra, cor de prioridade só na borda
/// superior e no título (nada de fundo colorido sólido).
class _ReminderCard extends StatefulWidget {
  final String title;
  final String content;
  final String author;
  final String dateLabel;
  final Color accent;
  final String levelLabel;
  final int delayIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReminderCard({
    required this.title,
    required this.content,
    required this.author,
    required this.dateLabel,
    required this.accent,
    required this.levelLabel,
    required this.delayIndex,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child:
          AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _hover
                      ? Color.alphaBlend(
                          widget.accent.withValues(alpha: 0.14),
                          inkSurfaceHover,
                        )
                      : Color.alphaBlend(
                          widget.accent.withValues(alpha: 0.08),
                          inkSurface,
                        ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hairline),
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Container(height: 3, color: widget.accent),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.title,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: widget.accent,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _CardIconButton(
                                      icon: Icons.edit_outlined,
                                      onTap: widget.onEdit,
                                    ),
                                    _CardIconButton(
                                      icon: Icons.delete_outline,
                                      danger: true,
                                      onTap: widget.onDelete,
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  child: Container(height: 1, color: hairline),
                                ),
                                Expanded(
                                  child: Text(
                                    widget.content.isEmpty
                                        ? "Sem descrição."
                                        : widget.content,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.55,
                                      color: panelIvory.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 12,
                                      color: panelSlateDim,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.dateLabel,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: panelSlateDim,
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.author.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 12,
                                        color: panelSlateDim,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          widget.author,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: panelSlateDim,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: DellalioLevelPin(
                        color: widget.accent,
                        label: "Prioridade: ${widget.levelLabel}",
                      ),
                    ),
                  ],
                ),
              )
              .animate(delay: (60 * widget.delayIndex).ms)
              .fadeIn(duration: 420.ms, curve: Curves.easeOut)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
    );
  }
}

class _CardIconButton extends StatefulWidget {
  final IconData icon;
  final bool danger;
  final VoidCallback onTap;
  const _CardIconButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<_CardIconButton> createState() => _CardIconButtonState();
}

class _CardIconButtonState extends State<_CardIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _hover ? inkSurfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 14,
            color: _hover
                ? (widget.danger ? panelRust : dellalioGoldSoft)
                : panelSlate,
          ),
        ),
      ),
    );
  }
}
