import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  
  void _showAddReminderDialog({DocumentSnapshot? existingDoc}) {
    final bool isEditing = existingDoc != null;
    final Map<String, dynamic>? existingData =
        isEditing ? existingDoc.data() as Map<String, dynamic>? : null;

    final TextEditingController titleCtrl =
        TextEditingController(text: existingData?['title']?.toString() ?? '');
    final TextEditingController contentCtrl =
        TextEditingController(text: existingData?['content']?.toString() ?? '');
    DateTime selectedDate = isEditing && existingData?['dateTime'] != null
        ? (existingData!['dateTime'] as Timestamp).toDate()
        : DateTime.now();
    TimeOfDay selectedTime = isEditing && existingData?['dateTime'] != null
        ? TimeOfDay.fromDateTime((existingData!['dateTime'] as Timestamp).toDate())
        : TimeOfDay.now();
    String selectedColor = existingData?['color']?.toString() ?? 'yellow';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(isEditing ? "Editar Lembrete" : "Novo Lembrete"),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Título")),
                TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: "Assunto")),
                const SizedBox(height: 15),
                ListTile(
                  title: Text("Data: ${DateFormat('dd/MM/yyyy').format(selectedDate)}"),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                        context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
                ListTile(
                  title: Text("Hora: ${selectedTime.format(context)}"),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    TimeOfDay? picked = await showTimePicker(context: context, initialTime: selectedTime);
                    if (picked != null) setDialogState(() => selectedTime = picked);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _colorOption('red', Colors.red, selectedColor, (c) => setDialogState(() => selectedColor = c)),
                    _colorOption('yellow', Colors.amber, selectedColor, (c) => setDialogState(() => selectedColor = c)),
                    _colorOption('green', Colors.green, selectedColor, (c) => setDialogState(() => selectedColor = c)),
                  ],
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {

                // final user = FirebaseAuth.instance.currentUser;
  
  // Busca o nome real antes de salvar
  String userName = await _getUserName();
                final DateTime finalDateTime = DateTime(
                    selectedDate.year, selectedDate.month, selectedDate.day,
                    selectedTime.hour, selectedTime.minute
                );

                final Map<String, dynamic> reminderData = {
                  'title': titleCtrl.text,
                  'content': contentCtrl.text,
                  'color': selectedColor,
                  'priority': selectedColor == 'red' ? 1 : selectedColor == 'yellow' ? 2 : 3,
                  'dateTime': Timestamp.fromDate(finalDateTime),
                };

                if (isEditing) {
                  await existingDoc.reference.update(reminderData);
                } else {
                  reminderData['author'] = userName;
                  reminderData['createdAt'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance.collection('reminders').add(reminderData);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(isEditing ? "Salvar Alterações" : "Salvar"),

            )
          ],
        );
      }),
    );
  }

  Widget _colorOption(String id, Color color, String selected, Function(String) onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: () => onTap(id),
        child: CircleAvatar(backgroundColor: color, radius: 18, child: selected == id ? const Icon(Icons.check, color: Colors.white) : null),
      ),
    );
  }

  Future<String> _getUserName() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return "Anônimo";

  try {
    // Busca o documento na coleção 'users' que tem o mesmo ID do usuário autenticado
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      // Retorna o campo 'nome' que está na sua imagem do Firestore
      return data['nome'] ?? "Usuário";
    }
  } catch (e) {
    print("Erro ao buscar nome: $e");
  }
  return "Usuário";
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("LEMBRETES")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddReminderDialog(),
        backgroundColor: const Color(0xFFD4AF37),
        child: const Icon(Icons.add, color: Colors.white),
      ),

      body: StreamBuilder<QuerySnapshot>(
       
        stream: FirebaseFirestore.instance.collection('reminders')
    .orderBy('createdAt', descending: true) // Isso não precisa de índice novo
    .snapshots(),
        builder: (context, snapshot) {
          // SE O ERRO FOR NO FIREBASE, O SNAPSHOT TERÁ UM ERRO
          if (snapshot.hasError) {
             return Center(child: Text("Erro: ${snapshot.error}", textAlign: TextAlign.center));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.8
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              DateTime dt = (data['dateTime'] as Timestamp).toDate();
              
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: data['color'] == 'red' ? Colors.red.shade100 : data['color'] == 'green' ? Colors.green.shade100 : Colors.amber.shade100,
                  border: Border.all(color: Colors.black87, width: 2.0),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5), topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20), bottomRight: Radius.circular(5),
                  ),
                  boxShadow: const [BoxShadow(color: Colors.black87, offset: Offset(3, 3))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(data['title'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                        GestureDetector(
                          onTap: () => _showAddReminderDialog(existingDoc: doc),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.0),
                            child: Icon(Icons.edit, size: 18, color: Colors.black87),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => doc.reference.delete(),
                          child: const Icon(Icons.delete_forever, size: 20, color: Colors.black87),
                        ),
                      ],
                    ),

                    const Divider(color: Colors.black45),
                    Text(data['content'].toString().toUpperCase(), style: const TextStyle(fontSize: 14,fontWeight: FontWeight.bold), maxLines: 4, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Text("📅 ${DateFormat('dd/MM HH:mm').format(dt)}".toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
// No seu itemBuilder do GridView:
Text("👤 ${data['author']}".toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}