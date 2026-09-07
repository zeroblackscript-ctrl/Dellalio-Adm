import 'dart:io';

import 'package:DELLALIO/core/people_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/dellalio_kit.dart';
import '../../core/theme.dart';
import '../../core/user_session.dart';

class TarefasAdminScreen extends StatefulWidget {
  const TarefasAdminScreen({super.key});

  @override
  State<TarefasAdminScreen> createState() => _TarefasAdminScreenState();
}

class _TarefasAdminScreenState extends State<TarefasAdminScreen>
    with SingleTickerProviderStateMixin {
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
    DocumentReference taskRef = FirebaseFirestore.instance
        .collection('tasks')
        .doc(taskId);
    batch.delete(taskRef);

    if (data['paraTodos'] == true) {
      final all = data['assignedToAll'];
      if (all is List) {
        for (final uid in all) {
          batch.delete(
            FirebaseFirestore.instance
                .collection('funcionarios')
                .doc(uid.toString())
                .collection('tarefas')
                .doc(taskId),
          );
          batch.delete(
            FirebaseFirestore.instance
                .collection('users')
                .doc(uid.toString())
                .collection('tarefas')
                .doc(taskId),
          );
        }
      }
    } else {
      final String? funcId = data['assignedTo']?.toString();
      if (funcId != null) {
        batch.delete(
          FirebaseFirestore.instance
              .collection('funcionarios')
              .doc(funcId)
              .collection('tarefas')
              .doc(taskId),
        );
        batch.delete(
          FirebaseFirestore.instance
              .collection('users')
              .doc(funcId)
              .collection('tarefas')
              .doc(taskId),
        );
      }
    }
    await batch.commit();
  }

  Future<void> _updateTaskStatus(
    String taskId,
    Map<String, dynamic> data,
    int newStatus,
  ) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    DocumentReference taskRef = FirebaseFirestore.instance
        .collection('tasks')
        .doc(taskId);
    batch.update(taskRef, {'status': newStatus});

    if (data['paraTodos'] == true) {
      final all = data['assignedToAll'];
      if (all is List) {
        for (final uid in all) {
          final uidStr = uid.toString();
          batch.set(
            FirebaseFirestore.instance
                .collection('funcionarios')
                .doc(uidStr)
                .collection('tarefas')
                .doc(taskId),
            {'status': newStatus},
            SetOptions(merge: true),
          );
          batch.set(
            FirebaseFirestore.instance
                .collection('users')
                .doc(uidStr)
                .collection('tarefas')
                .doc(taskId),
            {'status': newStatus},
            SetOptions(merge: true),
          );
        }
      }
    } else {
      final String? funcId = data['assignedTo']?.toString();
      if (funcId != null) {
        batch.set(
          FirebaseFirestore.instance
              .collection('funcionarios')
              .doc(funcId)
              .collection('tarefas')
              .doc(taskId),
          {'status': newStatus},
          SetOptions(merge: true),
        );
        batch.set(
          FirebaseFirestore.instance
              .collection('users')
              .doc(funcId)
              .collection('tarefas')
              .doc(taskId),
          {'status': newStatus},
          SetOptions(merge: true),
        );
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
          backgroundColor: inkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            "Nova tarefa",
            style: TextStyle(
              color: panelIvory,
              fontWeight: FontWeight.w500,
              fontSize: 17,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(controller: titleCtrl, label: "Título da tarefa"),
                const SizedBox(height: 10),
                _DialogField(
                  controller: obsCtrl,
                  label: "Observações",
                  maxLines: 2,
                ),
                _DialogRow(
                  label:
                      "Data limite: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                  icon: Icons.calendar_today_outlined,
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null)
                      dialogSetState(() => selectedDate = picked);
                  },
                ),
                _DialogDropdown(
                  label: "Nível de urgência",
                  value: selectedUrgencia,
                  items: urgenciaOptions,
                  onChanged: (val) =>
                      dialogSetState(() => selectedUrgencia = val!),
                ),
                _DialogCheckbox(
                  label: "Criar para todos",
                  value: criarParaTodos,
                  onChanged: (val) => dialogSetState(() {
                    criarParaTodos = val ?? false;
                    if (criarParaTodos) selectedFuncionarioId = null;
                  }),
                ),
                if (!criarParaTodos)
                  _DialogDropdown(
                    label: "Atribuir para",
                    value: selectedFuncionarioId,
                    items: pessoas
                        .map(
                          (p) =>
                              p.fullName.isNotEmpty ? p.fullName : "Sem nome",
                        )
                        .toList(),
                    itemValues: pessoas.map((p) => p.uid).toList(),
                    onChanged: (val) =>
                        dialogSetState(() => selectedFuncionarioId = val),
                  ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Mídias (fotos, vídeos, áudios)",
                    style: TextStyle(color: panelSlate, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                if (selectedMedia.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedMedia.map((file) {
                      return Stack(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: hairline),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                file,
                                fit: BoxFit.cover,
                                width: 60,
                                height: 60,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -4,
                            top: -4,
                            child: GestureDetector(
                              onTap: () => dialogSetState(
                                () => selectedMedia.remove(file),
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: panelRust,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
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
                  icon: Icon(Icons.attach_file, color: panelSlate),
                  label: Text(
                    "Adicionar mídia",
                    style: TextStyle(color: panelSlate),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
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
                final bool tituloOk = titleCtrl.text.isNotEmpty;
                final bool podeCriar = criarParaTodos
                    ? tituloOk
                    : (tituloOk && selectedFuncionarioId != null);
                if (!podeCriar) return;
                final adminUser = FirebaseAuth.instance.currentUser;
                final String? creatorUid = adminUser?.uid;
                String creatorName = 'Administrador';
                if (creatorUid != null) {
                  final creatorPerson = await PeopleService.fetchPerson(
                    creatorUid,
                  );
                  if (creatorPerson != null &&
                      creatorPerson.fullName.isNotEmpty) {
                    creatorName = creatorPerson.fullName;
                  }
                }
                Map<String, dynamic> taskData = {
                  'title': titleCtrl.text,
                  'observacoes': obsCtrl.text,
                  'deadline':
                      "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                  'urgencia': selectedUrgencia,
                  'status': 0,
                  'createdBy': creatorUid,
                  'createdByName': creatorName,
                  'createdAt': FieldValue.serverTimestamp(),
                };

                final List<String> uploadedMediaUrls = [];
                if (selectedMedia.isNotEmpty) {
                  for (final file in selectedMedia) {
                    final fileName =
                        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.isWindows ? '\\' : '/').last}';
                    final ref = FirebaseStorage.instance.ref().child(
                      'task_media/$fileName',
                    );
                    await ref.putFile(file);
                    final url = await ref.getDownloadURL();
                    uploadedMediaUrls.add(url);
                  }
                }
                taskData['mediaUrls'] = uploadedMediaUrls;

                if (criarParaTodos) {
                  final todos = pessoas
                      .where((p) => p.uid != adminUser?.uid)
                      .toList();
                  final List<String> allUids = todos.map((p) => p.uid).toList();
                  DocumentReference taskRef = FirebaseFirestore.instance
                      .collection('tasks')
                      .doc();
                  final dataComDestino = {
                    ...taskData,
                    'paraTodos': true,
                    'assignedTo': 'todos',
                    'assignedToAll': allUids,
                  };
                  WriteBatch batch = FirebaseFirestore.instance.batch();
                  batch.set(taskRef, dataComDestino);
                  for (final p in todos) {
                    batch.set(
                      FirebaseFirestore.instance
                          .collection('funcionarios')
                          .doc(p.uid)
                          .collection('tarefas')
                          .doc(taskRef.id),
                      dataComDestino,
                    );
                    batch.set(
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(p.uid)
                          .collection('tarefas')
                          .doc(taskRef.id),
                      dataComDestino,
                    );
                  }
                  await batch.commit();
                } else {
                  WriteBatch batch = FirebaseFirestore.instance.batch();
                  DocumentReference taskRef = FirebaseFirestore.instance
                      .collection('tasks')
                      .doc();
                  final dataComDestino = {
                    ...taskData,
                    'assignedTo': selectedFuncionarioId,
                  };
                  batch.set(taskRef, dataComDestino);
                  batch.set(
                    FirebaseFirestore.instance
                        .collection('funcionarios')
                        .doc(selectedFuncionarioId)
                        .collection('tarefas')
                        .doc(taskRef.id),
                    dataComDestino,
                  );
                  batch.set(
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(selectedFuncionarioId)
                        .collection('tarefas')
                        .doc(taskRef.id),
                    dataComDestino,
                  );
                  await batch.commit();
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text(
                "Criar",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditTaskDialog(
    String taskId,
    Map<String, dynamic> data,
  ) async {
    TextEditingController titleCtrl = TextEditingController(
      text: data['title'] ?? '',
    );
    TextEditingController obsCtrl = TextEditingController(
      text: data['observacoes'] ?? '',
    );
    DateTime selectedDate = DateTime.now();
    final String? deadlineStr = data['deadline'] as String?;
    if (deadlineStr != null && deadlineStr.contains('/')) {
      final parts = deadlineStr.split('/');
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null)
          selectedDate = DateTime(y, m, d);
      }
    }
    String selectedUrgencia = (data['urgencia'] as String?) ?? "Baixa";
    final List<String> urgenciaOptions = ["Baixa", "Média", "Alta"];
    String? selectedFuncionarioId = data['assignedTo'] as String?;
    final String? oldFuncionarioId = data['assignedTo'] as String?;
    final bool isParaTodos = data['paraTodos'] == true;
    final List<Person> pessoas = await PeopleService.fetchAllPeople();
    if (!mounted) return;
    if (selectedFuncionarioId != null &&
        !pessoas.any((p) => p.uid == selectedFuncionarioId)) {
      final p = await PeopleService.fetchPerson(selectedFuncionarioId);
      if (p != null) pessoas.add(p);
    }
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          backgroundColor: inkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            "Editar tarefa",
            style: TextStyle(
              color: panelIvory,
              fontWeight: FontWeight.w500,
              fontSize: 17,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(controller: titleCtrl, label: "Título da tarefa"),
                const SizedBox(height: 10),
                _DialogField(
                  controller: obsCtrl,
                  label: "Observações",
                  maxLines: 2,
                ),
                _DialogRow(
                  label:
                      "Data limite: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                  icon: Icons.calendar_today_outlined,
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null)
                      dialogSetState(() => selectedDate = picked);
                  },
                ),
                _DialogDropdown(
                  label: "Nível de urgência",
                  value: selectedUrgencia,
                  items: urgenciaOptions,
                  onChanged: (val) =>
                      dialogSetState(() => selectedUrgencia = val!),
                ),
                if (!isParaTodos)
                  _DialogDropdown(
                    label: "Atribuir para",
                    value: selectedFuncionarioId,
                    items: pessoas
                        .map(
                          (p) =>
                              p.fullName.isNotEmpty ? p.fullName : "Sem nome",
                        )
                        .toList(),
                    itemValues: pessoas.map((p) => p.uid).toList(),
                    onChanged: (val) =>
                        dialogSetState(() => selectedFuncionarioId = val),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
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
                if (titleCtrl.text.isEmpty) return;
                if (!isParaTodos && selectedFuncionarioId == null) return;
                final Map<String, dynamic> updatedData = {
                  ...data,
                  'title': titleCtrl.text,
                  'observacoes': obsCtrl.text,
                  'deadline':
                      "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                  'urgencia': selectedUrgencia,
                };
                if (!isParaTodos)
                  updatedData['assignedTo'] = selectedFuncionarioId;
                WriteBatch batch = FirebaseFirestore.instance.batch();
                DocumentReference taskRef = FirebaseFirestore.instance
                    .collection('tasks')
                    .doc(taskId);
                batch.update(taskRef, updatedData);
                if (isParaTodos) {
                  final all = data['assignedToAll'];
                  if (all is List) {
                    for (final uid in all) {
                      final uidStr = uid.toString();
                      batch.set(
                        FirebaseFirestore.instance
                            .collection('funcionarios')
                            .doc(uidStr)
                            .collection('tarefas')
                            .doc(taskId),
                        updatedData,
                        SetOptions(merge: true),
                      );
                      batch.set(
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(uidStr)
                            .collection('tarefas')
                            .doc(taskId),
                        updatedData,
                        SetOptions(merge: true),
                      );
                    }
                  }
                } else {
                  if (oldFuncionarioId != null &&
                      oldFuncionarioId != selectedFuncionarioId) {
                    batch.delete(
                      FirebaseFirestore.instance
                          .collection('funcionarios')
                          .doc(oldFuncionarioId)
                          .collection('tarefas')
                          .doc(taskId),
                    );
                    batch.delete(
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(oldFuncionarioId)
                          .collection('tarefas')
                          .doc(taskId),
                    );
                    batch.set(
                      FirebaseFirestore.instance
                          .collection('funcionarios')
                          .doc(selectedFuncionarioId)
                          .collection('tarefas')
                          .doc(taskId),
                      updatedData,
                    );
                    batch.set(
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(selectedFuncionarioId)
                          .collection('tarefas')
                          .doc(taskId),
                      updatedData,
                    );
                  } else {
                    batch.set(
                      FirebaseFirestore.instance
                          .collection('funcionarios')
                          .doc(selectedFuncionarioId)
                          .collection('tarefas')
                          .doc(taskId),
                      updatedData,
                      SetOptions(merge: true),
                    );
                    batch.set(
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(selectedFuncionarioId)
                          .collection('tarefas')
                          .doc(taskId),
                      updatedData,
                      SetOptions(merge: true),
                    );
                  }
                }
                await batch.commit();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text(
                "Salvar",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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
    return CircleAvatar(
      radius: radius,
      backgroundColor: inkSurfaceHover,
      backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
      child: fotoUrl.isEmpty
          ? Icon(Icons.person, size: radius, color: panelSlate)
          : null,
    );
  }

  String _formatCreatedAt(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final ts = createdAt as Timestamp;
      final dt = ts.toDate();
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return '';
    }
  }

  void _showTaskDetailsDialog(
    String taskId,
    Map<String, dynamic> data,
    bool canEdit,
  ) {
    final int status = data['status'] ?? 0;
    final bool recipient = _isRecipient(data);
    final bool isFinalizada = status == 3;
    if (recipient && status == 0) _updateTaskStatus(taskId, data, 1);
    final String criadoEm = _formatCreatedAt(data['createdAt']);
    final bool isParaTodos = data['paraTodos'] == true;
    final List<dynamic> mediaUrls = data['mediaUrls'] is List
        ? data['mediaUrls']
        : [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: inkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(
          (data['title'] ?? 'Tarefa').toString().toUpperCase(),
          style: TextStyle(
            color: panelIvory,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Observações",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: panelSlate,
                ),
              ),
              Text(
                (data['observacoes'] ?? '—').toString(),
                style: TextStyle(color: panelIvory),
              ),
              const SizedBox(height: 10),
              Text(
                "Prazo: ${data['deadline'] ?? '--/--/--'}",
                style: TextStyle(color: panelIvory),
              ),
              Text(
                "Urgência: ${data['urgencia'] ?? '—'}",
                style: TextStyle(color: panelIvory),
              ),
              if (isParaTodos)
                Text(
                  "Atribuído para: todos",
                  style: TextStyle(color: panelIvory),
                )
              else
                FutureBuilder<Person?>(
                  future: _getSenderPerson(data['assignedTo']?.toString()),
                  builder: (context, snap) {
                    final name =
                        snap.data?.fullName ?? data['assignedTo'] ?? '—';
                    return Text(
                      "Atribuído para: $name",
                      style: TextStyle(color: panelIvory),
                    );
                  },
                ),
              Text(
                "Criado por: ${data['createdByName'] ?? '—'}",
                style: TextStyle(color: panelIvory),
              ),
              if (criadoEm.isNotEmpty)
                Text(
                  "Criado em: $criadoEm",
                  style: TextStyle(color: panelIvory),
                ),
              if (mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  "Mídias",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: panelSlate,
                  ),
                ),
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
                          child: Image.network(
                            url,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (recipient && !isFinalizada && (status == 0 || status == 1))
            TextButton(
              onPressed: () {
                _updateTaskStatus(taskId, data, 2);
                Navigator.pop(ctx);
              },
              child: Text(
                "Marcar em processo",
                style: TextStyle(color: dellalioGoldSoft),
              ),
            ),
          if (recipient && !isFinalizada)
            TextButton(
              onPressed: () {
                _updateTaskStatus(taskId, data, 3);
                Navigator.pop(ctx);
              },
              child: const Text(
                "Finalizar",
                style: TextStyle(color: panelSage),
              ),
            ),
          if (canEdit)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showEditTaskDialog(taskId, data);
              },
              child: Text("Editar", style: TextStyle(color: panelSlate)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Fechar", style: TextStyle(color: panelSlate)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(34, 30, 34, 0),
                child:
                    Text(
                          "Gestão de tarefas",
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
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: dellalioGoldSoft,
                  unselectedLabelColor: panelSlate,
                  indicatorColor: dellalioGold,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                  tabs: const [
                    Tab(text: "Atribuídas a mim"),
                    Tab(text: "Atribuídas por mim"),
                    Tab(text: "Histórico"),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 80.ms),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTaskList(filter: _TaskFilter.assignedToMe),
                    _buildTaskList(filter: _TaskFilter.createdByMe),
                    _buildTaskList(filter: _TaskFilter.history),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 36,
            bottom: 32,
            child: _Fab(onPressed: _showCreateTaskDialog),
          ),
        ],
      ),
    );
  }

  Color _statusColor(int status) {
    switch (status) {
      case 0:
        return panelRust;
      case 1:
        return navyAccent;
      case 2:
        return dellalioGold;
      case 3:
        return panelSage;
      default:
        return panelSlate;
    }
  }

  String _statusLabel(int status) {
    switch (status) {
      case 0:
        return "NÃO LIDO";
      case 1:
        return "LIDO";
      case 2:
        return "EM PROCESSO";
      case 3:
        return "FINALIZADO";
      default:
        return "—";
    }
  }

  Widget _buildTaskList({required _TaskFilter filter}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: dellalioGold),
          );
        }
        final bool isAdmin = UserSession.isAdmin();

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final int status = data['status'] ?? 0;
          final bool isFinalizada = status == 3;
          final bool isParaTodos = data['paraTodos'] == true;
          switch (filter) {
            case _TaskFilter.assignedToMe:
              if (isFinalizada) return false;
              if (isParaTodos) {
                final all = data['assignedToAll'];
                return all is List && all.contains(_currentUid);
              }
              return data['assignedTo'] == _currentUid;
            case _TaskFilter.createdByMe:
              if (isFinalizada) return false;
              if (data['createdBy'] != _currentUid) return false;
              if (isParaTodos) return true;
              return data['assignedTo'] != _currentUid;
            case _TaskFilter.history:
              if (!isFinalizada) return false;
              if (isAdmin) return true;
              if (isParaTodos) {
                final all = data['assignedToAll'];
                if (all is List && all.contains(_currentUid)) return true;
              }
              return data['assignedTo'] == _currentUid ||
                  data['createdBy'] == _currentUid;
          }
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  filter == _TaskFilter.history
                      ? Icons.history
                      : Icons.task_alt,
                  size: 44,
                  color: panelSlateDim,
                ),
                const SizedBox(height: 12),
                Text(
                  filter == _TaskFilter.history
                      ? "Nenhuma tarefa no histórico."
                      : "Nenhuma tarefa por aqui.",
                  style: TextStyle(color: panelSlate, fontSize: 14),
                ),
              ],
            ),
          );
        }

        final screenWidth = MediaQuery.of(context).size.width;
        final crossAxisCount = screenWidth > 1200
            ? 4
            : screenWidth > 900
            ? 3
            : screenWidth > 600
            ? 2
            : 1;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(34, 22, 34, 30),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: 0.8,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            int status = data['status'] ?? 0;
            final bool canEdit =
                data['createdBy'] == _currentUid && status != 3;
            final bool isParaTodos = data['paraTodos'] == true;
            final String criadoEm = _formatCreatedAt(data['createdAt']);
            final List<dynamic> mediaUrls = data['mediaUrls'] is List
                ? data['mediaUrls']
                : [];

            return _TaskCard(
              title: (data['title'] ?? '').toString().toUpperCase(),
              observacoes: (data['observacoes'] ?? '').toString(),
              deadline: data['deadline'] ?? '--/--/--',
              createdByName: (data['createdByName'] ?? '—').toString(),
              createdAtLabel: criadoEm,
              accent: _statusColor(status),
              statusLabel: _statusLabel(status),
              isParaTodos: isParaTodos,
              canEdit: canEdit,
              mediaUrls: mediaUrls.map((e) => e.toString()).toList(),
              delayIndex: index % 12,
              avatarBuilder: () => FutureBuilder<Person?>(
                future: _getSenderPerson(data['createdBy']?.toString()),
                builder: (context, snap) =>
                    _senderAvatar(snap.data, radius: 11),
              ),
              onTap: () => _showTaskDetailsDialog(doc.id, data, canEdit),
              onEdit: () => _showEditTaskDialog(doc.id, data),
              onDelete: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: inkSurface,
                  title: Text(
                    "Excluir tarefa",
                    style: TextStyle(color: panelIvory),
                  ),
                  content: Text(
                    "Tem certeza que deseja remover esta tarefa?",
                    style: TextStyle(color: panelSlate),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("Não", style: TextStyle(color: panelSlate)),
                    ),
                    TextButton(
                      onPressed: () {
                        _deleteTask(doc.id, data);
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        "Sim, excluir",
                        style: TextStyle(color: panelRust),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

enum _TaskFilter { assignedToMe, createdByMe, history }

class _Fab extends StatelessWidget {
  final VoidCallback onPressed;
  const _Fab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
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
    );
  }
}

class _TaskCard extends StatefulWidget {
  final String title;
  final String observacoes;
  final String deadline;
  final String createdByName;
  final String createdAtLabel;
  final Color accent;
  final String statusLabel;
  final bool isParaTodos;
  final bool canEdit;
  final List<String> mediaUrls;
  final int delayIndex;
  final Widget Function() avatarBuilder;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.title,
    required this.observacoes,
    required this.deadline,
    required this.createdByName,
    required this.createdAtLabel,
    required this.accent,
    required this.statusLabel,
    required this.isParaTodos,
    required this.canEdit,
    required this.mediaUrls,
    required this.delayIndex,
    required this.avatarBuilder,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
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
                  child: Column(
                    children: [
                      Container(height: 3, color: widget.accent),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
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
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: panelIvory,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  widget.avatarBuilder(),
                                  if (widget.canEdit) ...[
                                    const SizedBox(width: 2),
                                    GestureDetector(
                                      onTap: widget.onEdit,
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 13,
                                        color: panelSlate,
                                      ),
                                    ),
                                  ],
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
                                  widget.observacoes,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: panelIvory.withValues(alpha: 0.85),
                                  ),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.mediaUrls.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 42,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: widget.mediaUrls.length,
                                    itemBuilder: (context, i) => Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          widget.mediaUrls[i],
                                          width: 42,
                                          height: 42,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Container(height: 1, color: hairline),
                              ),
                              Text(
                                "${widget.createdByName} ${widget.createdAtLabel.isNotEmpty ? '• ${widget.createdAtLabel}' : ''}",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontStyle: FontStyle.italic,
                                  color: panelSlateDim,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.deadline,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: panelIvory,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (widget.canEdit)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: GestureDetector(
                                        onTap: widget.onDelete,
                                        child: Icon(
                                          Icons.delete_outline,
                                          size: 13,
                                          color: panelRust,
                                        ),
                                      ),
                                    ),
                                  if (widget.isParaTodos) ...[
                                    const DellalioBadge(
                                      label: "TODOS",
                                      color: panelViolet,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  DellalioBadge(
                                    label: widget.statusLabel,
                                    color: widget.accent,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .animate(delay: (55 * widget.delayIndex).ms)
                .fadeIn(duration: 420.ms, curve: Curves.easeOut)
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
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

class _DialogDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final List<String>? itemValues;
  final ValueChanged<String?> onChanged;

  const _DialogDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemValues,
  });

  @override
  Widget build(BuildContext context) {
    final values = itemValues ?? items;
    return DropdownButtonFormField<String>(
      dropdownColor: inkSurface,
      style: TextStyle(color: panelIvory),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: panelSlate),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: hairline),
        ),
      ),
      initialValue: value,
      items: List.generate(
        items.length,
        (i) => DropdownMenuItem(value: values[i], child: Text(items[i])),
      ),
      onChanged: onChanged,
    );
  }
}

class _DialogCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _DialogCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: panelIvory)),
      value: value,
      activeColor: dellalioGold,
      onChanged: onChanged,
    );
  }
}
