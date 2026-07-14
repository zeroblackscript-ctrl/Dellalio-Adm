import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AgendaScreen extends StatefulWidget {
  @override
  _AgendaScreenState createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _displayMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // Calcula quantos dias tem o mês atual para desenhar o grid
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
    final startWeekday =
        firstDayOfMonth.weekday % 7; // Ajuste para começar no Domingo/Segunda

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showMonthPicker(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat(
                  'MMMM yyyy',
                  'pt_BR',
                ).format(_displayMonth).toUpperCase(),
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.arrow_drop_down, color: Colors.black),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildWeekHeader(),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.65,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: daysInMonth + startWeekday,
              itemBuilder: (context, index) {
                if (index < startWeekday) return SizedBox.shrink();
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
    );
  }

  Widget _buildWeekHeader() {
    return Row(
      children: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
          .map(
            (d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDayCell(DateTime day) {
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

        return GestureDetector(
          // Ao clicar, abrimos um Dialog que lista tudo ou permite adicionar um novo
          onTap: () => _showDayDetailsDialog(day, docs),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Text(
                  "${day.day}",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                // Exibe uma pequena barra para cada anotação encontrada
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final color = Color(
                    int.tryParse(
                          data['userColor']?.toString().replaceFirst(
                                '#',
                                '0xff',
                              ) ??
                              '0xffEEEEEE',
                        ) ??
                        0xffEEEEEE,
                  );
                  return Container(
                    margin: EdgeInsets.all(1),
                    width: double.infinity,
                    color: color.withValues(alpha: 0.5),
                    child: Center(
                      child: Text(
                        data['userName'].toString().toUpperCase(),
                        style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDayDetailsDialog(DateTime day, List<QueryDocumentSnapshot> docs) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Notas do dia ${DateFormat('dd/MM/yyyy').format(day)}"),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['text'] ?? 'Sem título'),
                      subtitle: Text("Por: ${data['userName']}"),
                      // CORREÇÃO AQUI: Chama o seu diálogo de edição passando o doc específico
                      onTap: () {
                        Navigator.pop(context); // Fecha a lista
                        _showPostItDialog(day, docs[index]); // Abre a nota
                      },
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Fecha a lista
                  _showPostItDialog(
                    day,
                    null,
                  ); // Abre diálogo vazio para nova nota
                },
                child: Text("Adicionar nova nota"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPostItDialog(DateTime day, DocumentSnapshot? doc) async {
    final user = FirebaseAuth.instance.currentUser!;
    // Campos separados
    final descController = TextEditingController(
      text: doc != null ? (doc.data() as Map)['text'] : '',
    );
    final infoController = TextEditingController(
      text: doc != null ? (doc.data() as Map)['info'] ?? '' : '',
    );

    final data = doc != null ? doc.data() as Map<String, dynamic> : null;
    final isOwner = doc == null || data?['userId'] == user.uid;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxWidth: 450),
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            // Permite scroll se o texto for longo
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "DATA: ${DateFormat('dd/MM/yyyy').format(day)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.indigo,
                  ),
                ),
                Divider(),

                if (data != null) ...[
                  Text(
                    "CRIADO POR:",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Color(
                          int.tryParse(
                                data['userColor']?.toString().replaceFirst(
                                      '#',
                                      '0xff',
                                    ) ??
                                    '0xffEEEEEE',
                              ) ??
                              0xffEEEEEE,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        data['userName'] ?? 'Desconhecido',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],

                // Campo 1: O que será feito
                Text(
                  "O QUE SERÁ FEITO:",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: descController,
                  enabled: isOwner,
                  decoration: InputDecoration(
                    hintText: "Título ou tarefa principal...",
                  ),
                ),

                SizedBox(height: 16),

                // Campo 2: Informações Adicionais (O que faltava)
                Text(
                  "INFORMAÇÕES ADICIONAIS:",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: infoController,
                  enabled: isOwner,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Medidas, observações ou notas de clientes...",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (doc != null && isOwner)
                      TextButton(
                        onPressed: () {
                          doc.reference.delete();
                          Navigator.pop(context);
                        },
                        child: Text(
                          "EXCLUIR",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    if (isOwner)
                      ElevatedButton(
                        onPressed: () async {
                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .get();
                          final userData =
                              userDoc.data() as Map<String, dynamic>?;

                          final Map<String, dynamic> notaData = {
                            'userId': user.uid,
                            'userName': userData?['nome'] ?? 'Usuário',
                            'userColor': userData?['userColor'] ?? '#FF5733',
                            'text': descController.text,
                            'info': infoController.text,
                            'date': Timestamp.fromDate(day),
                          };

                          if (doc == null) {
                            // Cria nova nota com ID único
                            await FirebaseFirestore.instance
                                .collection('agenda')
                                .add(notaData);
                          } else {
                            // Atualiza nota existente
                            await doc.reference.update(notaData);
                          }

                          Navigator.pop(context);
                        },
                        child: Text("SALVAR"),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMonthPicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _displayMonth,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _displayMonth = picked);
  }
}
