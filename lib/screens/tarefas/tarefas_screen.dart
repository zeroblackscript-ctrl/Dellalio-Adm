import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:DELLALIO/core/people_service.dart';
import '../../core/theme.dart';
import '../../core/user_session.dart';

class TarefasAdminScreen extends StatefulWidget {
  const TarefasAdminScreen({super.key});

  @override
  State<TarefasAdminScreen> createState() => _TarefasAdminScreenState();
}

class _TarefasAdminScreenState extends State<TarefasAdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isRecipient(Map<String, dynamic> data) {
    if (data['assignedTo'] == _currentUid) return true;
    if (data['paraTodos'] == true) {
      final all = data['assignedToAll'];
      if (all is List) return all.contains(_currentUid);
    }
    return false;
  }

  Future<void> _deleteTask(String taskId, Map<String, dynamic> data) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    DocumentReference taskRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
    batch.delete(taskRef);

    if (data['paraTodos'] == true) {
      final all = data['assignedToAll'];
      if (all is List) {
        for (final uid in all) {
          batch.delete(FirebaseFirestore.instance.collection('funcionarios').doc(uid.toString()).collection('tarefas').doc(taskId));
          batch.delete(FirebaseFirestore.instance.collection('users').doc(uid.toString()).collection('tarefas').doc(taskId));
        }
      }
    } else {
      final String? funcId = data['assignedTo']?.toString();
      if (funcId != null) {
        batch.delete(FirebaseFirestore.instance.collection('funcionarios').doc(funcId).collection('tarefas').doc(taskId));
        batch.delete(FirebaseFirestore.instance.collection('users').doc(funcId).collection('tarefas').doc(taskId));
      }
    }
    await batch.commit();
  }

  Future<void> _updateTaskStatus(String taskId, Map<String, dynamic> data, int newStatus) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    DocumentReference taskRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
    batch.update(taskRef, {'status': newStatus});

    if (data['paraTodos'] == true) {
      final all = data['assignedToAll'];
      if (all is List) {
        for (final uid in all) {
          final uidStr = uid.toString();
          batch.set(FirebaseFirestore.instance.collection('funcionarios').doc(uidStr).collection('tarefas').doc(taskId), {'status': newStatus}, SetOptions(merge: true));
          batch.set(FirebaseFirestore.instance.collection('users').doc(uidStr).collection('tarefas').doc(taskId), {'status': newStatus}, SetOptions(merge: true));
        }
      }
    } else {
      final String? funcId = data['assignedTo']?.toString();
      if (funcId != null) {
        batch.set(FirebaseFirestore.instance.collection('funcionarios').doc(funcId).collection('tarefas').doc(taskId), {'status': newStatus}, SetOptions(merge: true));
        batch.set(FirebaseFirestore.instance.collection('users').doc(funcId).collection('tarefas').doc(taskId), {'status': newStatus}, SetOptions(merge: true));
      }
    }
    await batch.commit();
  }

  Future<void> _showCreateTaskDialog() async {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController obsCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String? selectedFuncionarioId;
    String selectedUrgencia = "Baixa";
    bool criarParaTodos = false;
    final List<String> urgenciaOptions = ["Baixa", "Média", "Alta"];
    final List<Person> pessoas = await PeopleService.fetchAllPeople();
    final List<File> selectedMedia = [];
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          backgroundColor: DellalioTheme.darkSurface,
          title: const Text("NOVA TAREFA", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "TÍTULO DA TAREFA")),
              TextField(controller: obsCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "OBSERVAÇÕES"), maxLines: 2),
              ListTile(title: Text("DATA LIMITE: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}", style: const TextStyle(color: Colors.white)), trailing: const Icon(Icons.calendar_today, color: Colors.white), onTap: () async {
                DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                if (picked != null) dialogSetState(() => selectedDate = picked);
              }),
              DropdownButtonFormField<String>(
                dropdownColor: DellalioTheme.darkSurface, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "NÍVEL DE URGÊNCIA:"),
                initialValue: selectedUrgencia,
                items: urgenciaOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (val) => dialogSetState(() => selectedUrgencia = val!),
              ),
              CheckboxListTile(
                title: const Text("CRIAR PARA TODOS", style: TextStyle(color: Colors.white)),
                value: criarParaTodos,
                activeColor: DellalioTheme.accentGold,
                onChanged: (val) => dialogSetState(() { criarParaTodos = val ?? false; if (criarParaTodos) selectedFuncionarioId = null; }),
              ),
              if (!criarParaTodos)
                DropdownButtonFormField<String>(
                  dropdownColor: DellalioTheme.darkSurface, style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "ATRIBUIR PARA:"),
                  items: pessoas.map((p) => DropdownMenuItem(value: p.uid, child: Text(p.fullName.isNotEmpty ? p.fullName : "Sem nome"))).toList(),
                  onChanged: (val) => dialogSetState(() => selectedFuncionarioId = val),
                ),
              const SizedBox(height: 16),
              const Text("MÍDIAS (FOTOS, VÍDEOS, ÁUDIOS):", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              if (selectedMedia.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedMedia.map((file) {
                    return Stack(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(file, fit: BoxFit.cover, width: 60, height: 60),
                          ),
                        ),
                        Positioned(
                          right: -4, top: -4,
                          child: GestureDetector(
                            onTap: () => dialogSetState(() => selectedMedia.remove(file)),
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              TextButton.icon(
                onPressed: () async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? media = await picker.pickMedia();
                  if (media != null) {
                    dialogSetState(() => selectedMedia.add(File(media.path)));
                  }
                },
                icon: const Icon(Icons.attach_file, color: Colors.white70),
                label: const Text("ADICIONAR MÍDIA", style: TextStyle(color: Colors.white70)),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
            ElevatedButton(
              onPressed: () async {
                final bool tituloOk = titleCtrl.text.isNotEmpty;
                final bool podeCriar = criarParaTodos ? tituloOk : (tituloOk && selectedFuncionarioId != null);
                if (!podeCriar) return;
                final adminUser = FirebaseAuth.instance.currentUser;
                final String? creatorUid = adminUser?.uid;
                String creatorName = 'Administrador';
                if (creatorUid != null) {
                  final creatorPerson = await PeopleService.fetchPerson(creatorUid);
                  if (creatorPerson != null && creatorPerson.fullName.isNotEmpty) creatorName = creatorPerson.fullName;
                }
                Map<String, dynamic> taskData = {
                  'title': titleCtrl.text, 'observacoes': obsCtrl.text,
                  'deadline': "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                  'urgencia': selectedUrgencia, 'status': 0,
                  'createdBy': creatorUid, 'createdByName': creatorName, 'createdAt': FieldValue.serverTimestamp(),
                };

                // Upload das mídias para o Firebase Storage
                final List<String> uploadedMediaUrls = [];
                if (selectedMedia.isNotEmpty) {
                  for (final file in selectedMedia) {
                    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.isWindows ? '\\' : '/').last}';
                    final ref = FirebaseStorage.instance.ref().child('task_media/$fileName');
                    await ref.putFile(file);
                    final url = await ref.getDownloadURL();
                    uploadedMediaUrls.add(url);
                  }
                }
                taskData['mediaUrls'] = uploadedMediaUrls;

                if (criarParaTodos) {
                  final todos = pessoas.where((p) => p.uid != adminUser?.uid).toList();
                  final List<String> allUids = todos.map((p) => p.uid).toList();
                  DocumentReference taskRef = FirebaseFirestore.instance.collection('tasks').doc();
                  final dataComDestino = {...taskData, 'paraTodos': true, 'assignedTo': 'todos', 'assignedToAll': allUids};
                  WriteBatch batch = FirebaseFirestore.instance.batch();
                  batch.set(taskRef, dataComDestino);
                  for (final p in todos) {
                    batch.set(FirebaseFirestore.instance.collection('funcionarios').doc(p.uid).collection('tarefas').doc(taskRef.id), dataComDestino);
                    batch.set(FirebaseFirestore.instance.collection('users').doc(p.uid).collection('tarefas').doc(taskRef.id), dataComDestino);
                  }
                  await batch.commit();
                } else {
                  WriteBatch batch = FirebaseFirestore.instance.batch();
                  DocumentReference taskRef = FirebaseFirestore.instance.collection('tasks').doc();
                  final dataComDestino = {...taskData, 'assignedTo': selectedFuncionarioId};
                  batch.set(taskRef, dataComDestino);
                  batch.set(FirebaseFirestore.instance.collection('funcionarios').doc(selectedFuncionarioId).collection('tarefas').doc(taskRef.id), dataComDestino);
                  batch.set(FirebaseFirestore.instance.collection('users').doc(selectedFuncionarioId).collection('tarefas').doc(taskRef.id), dataComDestino);
                  await batch.commit();
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text("CRIAR"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditTaskDialog(String taskId, Map<String, dynamic> data) async {
    TextEditingController titleCtrl = TextEditingController(text: data['title'] ?? '');
    TextEditingController obsCtrl = TextEditingController(text: data['observacoes'] ?? '');
    DateTime selectedDate = DateTime.now();
    final String? deadlineStr = data['deadline'] as String?;
    if (deadlineStr != null && deadlineStr.contains('/')) {
      final parts = deadlineStr.split('/');
      if (parts.length == 3) { final d = int.tryParse(parts[0]); final m = int.tryParse(parts[1]); final y = int.tryParse(parts[2]); if (d != null && m != null && y != null) selectedDate = DateTime(y, m, d); }
    }
    String selectedUrgencia = (data['urgencia'] as String?) ?? "Baixa";
    final List<String> urgenciaOptions = ["Baixa", "Média", "Alta"];
    String? selectedFuncionarioId = data['assignedTo'] as String?;
    final String? oldFuncionarioId = data['assignedTo'] as String?;
    final bool isParaTodos = data['paraTodos'] == true;
    final List<Person> pessoas = await PeopleService.fetchAllPeople();
    if (!mounted) return;
    if (selectedFuncionarioId != null && !pessoas.any((p) => p.uid == selectedFuncionarioId)) {
      final p = await PeopleService.fetchPerson(selectedFuncionarioId);
      if (p != null) pessoas.add(p);
    }
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          backgroundColor: DellalioTheme.darkSurface,
          title: const Text("EDITAR TAREFA", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "TÍTULO DA TAREFA")),
              TextField(controller: obsCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "OBSERVAÇÕES"), maxLines: 2),
              ListTile(title: Text("DATA LIMITE: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}", style: const TextStyle(color: Colors.white)), trailing: const Icon(Icons.calendar_today, color: Colors.white), onTap: () async {
                DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (picked != null) dialogSetState(() => selectedDate = picked);
              }),
              DropdownButtonFormField<String>(
                dropdownColor: DellalioTheme.darkSurface, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "NÍVEL DE URGÊNCIA:"),
                initialValue: selectedUrgencia,
                items: urgenciaOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (val) => dialogSetState(() => selectedUrgencia = val!),
              ),
              if (!isParaTodos)
                DropdownButtonFormField<String>(
                  dropdownColor: DellalioTheme.darkSurface, style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "ATRIBUIR PARA:"),
                  initialValue: selectedFuncionarioId,
                  items: pessoas.map((p) => DropdownMenuItem(value: p.uid, child: Text(p.fullName.isNotEmpty ? p.fullName : "Sem nome"))).toList(),
                  onChanged: (val) => dialogSetState(() => selectedFuncionarioId = val),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                if (!isParaTodos && selectedFuncionarioId == null) return;
                final Map<String, dynamic> updatedData = {...data, 'title': titleCtrl.text, 'observacoes': obsCtrl.text, 'deadline': "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}", 'urgencia': selectedUrgencia};
                if (!isParaTodos) updatedData['assignedTo'] = selectedFuncionarioId;
                WriteBatch batch = FirebaseFirestore.instance.batch();
                DocumentReference taskRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
                batch.update(taskRef, updatedData);
                if (isParaTodos) {
                  final all = data['assignedToAll'];
                  if (all is List) {
                    for (final uid in all) {
                      final uidStr = uid.toString();
                      batch.set(FirebaseFirestore.instance.collection('funcionarios').doc(uidStr).collection('tarefas').doc(taskId), updatedData, SetOptions(merge: true));
                      batch.set(FirebaseFirestore.instance.collection('users').doc(uidStr).collection('tarefas').doc(taskId), updatedData, SetOptions(merge: true));
                    }
                  }
                } else {
                  if (oldFuncionarioId != null && oldFuncionarioId != selectedFuncionarioId) {
                    batch.delete(FirebaseFirestore.instance.collection('funcionarios').doc(oldFuncionarioId).collection('tarefas').doc(taskId));
                    batch.delete(FirebaseFirestore.instance.collection('users').doc(oldFuncionarioId).collection('tarefas').doc(taskId));
                    batch.set(FirebaseFirestore.instance.collection('funcionarios').doc(selectedFuncionarioId).collection('tarefas').doc(taskId), updatedData);
                    batch.set(FirebaseFirestore.instance.collection('users').doc(selectedFuncionarioId).collection('tarefas').doc(taskId), updatedData);
                  } else {
                    batch.set(FirebaseFirestore.instance.collection('funcionarios').doc(selectedFuncionarioId).collection('tarefas').doc(taskId), updatedData, SetOptions(merge: true));
                    batch.set(FirebaseFirestore.instance.collection('users').doc(selectedFuncionarioId).collection('tarefas').doc(taskId), updatedData, SetOptions(merge: true));
                  }
                }
                await batch.commit();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text("SALVAR"),
            ),
          ],
        ),
      ),
    );
  }

  Future<Person?> _getSenderPerson(String? createdBy) async {
    if (createdBy == null || createdBy.isEmpty) return null;
    return PeopleService.fetchPerson(createdBy);
  }

  Widget _senderAvatar(Person? person, {double radius = 13}) {
    final fotoUrl = person?.fotoUrl ?? '';
    return CircleAvatar(radius: radius, backgroundColor: Colors.black12, backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null, child: fotoUrl.isEmpty ? Icon(Icons.person, size: radius, color: Colors.black54) : null);
  }

  String _formatCreatedAt(dynamic createdAt) {
    if (createdAt == null) return '';
    try { final ts = createdAt as Timestamp; final dt = ts.toDate(); return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}"; } catch (_) { return ''; }
  }

  void _showTaskDetailsDialog(String taskId, Map<String, dynamic> data, bool canEdit) {
    final int status = data['status'] ?? 0;
    final bool recipient = _isRecipient(data);
    final bool isFinalizada = status == 3;
    if (recipient && status == 0) _updateTaskStatus(taskId, data, 1);
    final String criadoEm = _formatCreatedAt(data['createdAt']);
    final bool isParaTodos = data['paraTodos'] == true;
    final List<dynamic> mediaUrls = data['mediaUrls'] is List ? data['mediaUrls'] : [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DellalioTheme.darkSurface,
        title: Text((data['title'] ?? 'TAREFA').toString().toUpperCase(), style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("OBSERVAÇÕES:", style: TextStyle(fontWeight: FontWeight.bold, color: DellalioTheme.textSecondary)),
            Text((data['observacoes'] ?? '—').toString(), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            Text("PRAZO: ${data['deadline'] ?? '--/--/--'}", style: const TextStyle(color: Colors.white)),
            Text("URGÊNCIA: ${data['urgencia'] ?? '—'}", style: const TextStyle(color: Colors.white)),
            if (isParaTodos) const Text("ATRIBUÍDO PARA: TODOS", style: TextStyle(color: Colors.white)) else
              FutureBuilder<Person?>(
                future: _getSenderPerson(data['assignedTo']?.toString()),
                builder: (context, snap) { final name = snap.data?.fullName ?? data['assignedTo'] ?? '—'; return Text("ATRIBUÍDO PARA: $name", style: const TextStyle(color: Colors.white)); },
              ),
            Text("CRIADO POR: ${data['createdByName'] ?? '—'}", style: const TextStyle(color: Colors.white)),
            if (criadoEm.isNotEmpty) Text("CRIADO EM: $criadoEm", style: const TextStyle(color: Colors.white)),
            if (mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text("MÍDIAS:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: mediaUrls.length,
                  itemBuilder: (context, index) {
                    final url = mediaUrls[index].toString();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(url, width: 120, height: 120, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
            ],
          ]),
        ),
        actions: [
          if (recipient && !isFinalizada && (status == 0 || status == 1))
            TextButton(onPressed: () { _updateTaskStatus(taskId, data, 2); Navigator.pop(ctx); }, child: const Text("MARCAR EM PROCESSO")),
          if (recipient && !isFinalizada)
            TextButton(onPressed: () { _updateTaskStatus(taskId, data, 3); Navigator.pop(ctx); }, child: const Text("FINALIZAR", style: TextStyle(color: Colors.green))),
          if (canEdit) TextButton(onPressed: () { Navigator.pop(ctx); _showEditTaskDialog(taskId, data); }, child: const Text("EDITAR")),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FECHAR")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DellalioTheme.darkBackground,
      appBar: AppBar(
        title: const Text("GESTÃO DE TAREFAS", style: DellalioTheme.titleStyle),
        backgroundColor: DellalioTheme.darkPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: DellalioTheme.accentBlue,
          unselectedLabelColor: const Color(0xFFB0BEC5),
          indicatorColor: DellalioTheme.accentBlue,
          tabs: const [
            Tab(text: "TAREFAS ATRIBUÍDAS A MIM"),
            Tab(text: "ATRIBUÍDAS POR MIM"),
            Tab(text: "HISTÓRICO"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTaskDialog,
        backgroundColor: DellalioTheme.accentGold,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTaskList(filter: _TaskFilter.assignedToMe),
          _buildTaskList(filter: _TaskFilter.createdByMe),
          _buildTaskList(filter: _TaskFilter.history),
        ],
      ),
    );
  }

  Widget _buildTaskList({required _TaskFilter filter}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tasks').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final bool isAdmin = UserSession.isAdmin();

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final int status = data['status'] ?? 0;
          final bool isFinalizada = status == 3;
          final bool isParaTodos = data['paraTodos'] == true;
          switch (filter) {
            case _TaskFilter.assignedToMe: if (isFinalizada) return false; if (isParaTodos) { final all = data['assignedToAll']; return all is List && all.contains(_currentUid); } return data['assignedTo'] == _currentUid;
            case _TaskFilter.createdByMe: if (isFinalizada) return false; if (data['createdBy'] != _currentUid) return false; if (isParaTodos) return true; return data['assignedTo'] != _currentUid;
            case _TaskFilter.history: if (!isFinalizada) return false; if (isAdmin) return true; if (isParaTodos) { final all = data['assignedToAll']; if (all is List && all.contains(_currentUid)) return true; } return data['assignedTo'] == _currentUid || data['createdBy'] == _currentUid;
          }
        }).toList();

        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(filter == _TaskFilter.history ? Icons.history : Icons.task_alt, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(filter == _TaskFilter.history ? "NENHUMA TAREFA NO HISTÓRICO." : "NENHUMA TAREFA POR AQUI.", style: TextStyle(color: DellalioTheme.textOnDark, fontSize: 16)),
          ]));
        }

        final screenWidth = MediaQuery.of(context).size.width;
        final crossAxisCount = screenWidth > 1200 ? 4 : screenWidth > 900 ? 3 : screenWidth > 600 ? 2 : 1;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: 7, mainAxisSpacing: 16, childAspectRatio: 0.65),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            int status = data['status'] ?? 0;
            final bool canEdit = data['createdBy'] == _currentUid && status != 3;
            final bool isParaTodos = data['paraTodos'] == true;
            Color color; String label;
            switch (status) { case 0: color = Colors.redAccent; label = "NÃO LIDO"; break; case 1: color = Colors.blueAccent; label = "LIDO"; break; case 2: color = Colors.amber; label = "EM PROCESSO"; break; case 3: color = Colors.green; label = "FINALIZADO"; break; default: color = Colors.grey; label = "—"; }
            final String criadoEm = _formatCreatedAt(data['createdAt']);
            final List<dynamic> mediaUrls = data['mediaUrls'] is List ? data['mediaUrls'] : [];

            return InkWell(
              onTap: () => _showTaskDetailsDialog(doc.id, data, canEdit),
              child: Container(
                margin: const EdgeInsets.all(4), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF9C4), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(2), topRight: Radius.circular(15), bottomLeft: Radius.circular(2), bottomRight: Radius.circular(2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text((data['title'] ?? '').toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    FutureBuilder<Person?>(future: _getSenderPerson(data['createdBy']?.toString()), builder: (context, snap) => _senderAvatar(snap.data, radius: 12)),
                    if (canEdit) InkWell(onTap: () => _showEditTaskDialog(doc.id, data), child: const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.edit, size: 14, color: Colors.black54))),
                  ]),
                  const Divider(),
                  const SizedBox(height: 4),
                  Expanded(child: Text((data['observacoes'] ?? '').toString().toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.black), overflow: TextOverflow.fade)),
                  if (mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: mediaUrls.length,
                        itemBuilder: (context, index) {
                          final url = mediaUrls[index].toString();
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(url, width: 50, height: 50, fit: BoxFit.cover),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const Divider(color: Colors.black12),
                  Padding(padding: const EdgeInsets.only(bottom: 2), child: Text("${data['createdByName'] ?? '—'} ${criadoEm.isNotEmpty ? '• $criadoEm' : ''}", style: const TextStyle(fontSize: 9, color: Colors.black54, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Row(children: [
                    Expanded(child: Text(data['deadline'] ?? '--/--/--', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 4),
                    if (canEdit) Padding(padding: const EdgeInsets.only(right: 2), child: GestureDetector(onTap: () { showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Excluir Tarefa"), content: const Text("Tem certeza que deseja remover esta tarefa?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Não")), TextButton(onPressed: () { _deleteTask(doc.id, data); Navigator.pop(ctx); }, child: const Text("Sim, excluir", style: TextStyle(color: Colors.red)))],)); }, child: const Icon(Icons.delete_outline, size: 14, color: Colors.red))),
                    if (isParaTodos) Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), margin: const EdgeInsets.only(right: 2), decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)), child: const Text("TODOS", style: TextStyle(color: Colors.purple, fontSize: 8, fontWeight: FontWeight.bold))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)), child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold))),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

enum _TaskFilter { assignedToMe, createdByMe, history }