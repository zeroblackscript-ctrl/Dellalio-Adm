import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:DELLALIO/core/people_service.dart';
import '../../core/user_session.dart';

/// Status da tarefa:
/// 0 = Não Lido
/// 1 = Lido (automático ao abrir a tarefa)
/// 2 = Em Processo
/// 3 = Finalizado

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

  /// Verifica se o usuário atual é o destinatário da tarefa
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

    // Se for tarefa "para todos", remove de todas as subcoleções
    if (data['paraTodos'] == true) {
      final all = data['assignedToAll'];
      if (all is List) {
        for (final uid in all) {
          // Tenta remover de funcionarios
          batch.delete(
            FirebaseFirestore.instance
                .collection('funcionarios')
                .doc(uid.toString())
                .collection('tarefas')
                .doc(taskId),
          );
          // Tenta remover de users também
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
      // Tarefa individual
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

  Future<void> _updateTaskStatus(String taskId, Map<String, dynamic> data, int newStatus) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();

    DocumentReference taskRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
    batch.update(taskRef, {'status': newStatus});

    // Se for tarefa "para todos", atualiza em todas as subcoleções
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

  // Dialog para criar nova tarefa.
  // Se [criarParaTodos] estiver marcado, cria UM único documento na coleção
  // 'tasks' (com flag paraTodos e array assignedToAll), mas replica nas
  // subcoleções de cada pessoa para que todos possam ver.
  Future<void> _showCreateTaskDialog() async {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController obsCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String? selectedFuncionarioId;
    String selectedUrgencia = "Baixa";
    bool criarParaTodos = false;
    final List<String> urgenciaOptions = ["Baixa", "Média", "Alta"];

    final List<Person> pessoas = await PeopleService.fetchAllPeople();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: const Text("Nova Tarefa"),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Título da Tarefa")),
              TextField(controller: obsCtrl, decoration: const InputDecoration(labelText: "Observações"), maxLines: 2),

              ListTile(
                title: Text("Data Limite: ${"${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"}"),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    dialogSetState(() => selectedDate = picked);
                  }
                },
              ),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Nível de Urgência:"),
                initialValue: selectedUrgencia,
                items: urgenciaOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (val) => dialogSetState(() => selectedUrgencia = val!),
              ),

              // Checkbox "Criar para todos"
              CheckboxListTile(
                title: const Text("Criar para todos"),
                value: criarParaTodos,
                onChanged: (val) => dialogSetState(() {
                  criarParaTodos = val ?? false;
                  if (criarParaTodos) selectedFuncionarioId = null;
                }),
              ),

              if (!criarParaTodos)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Atribuir para:"),
                  items: pessoas.map((p) {
                    return DropdownMenuItem(
                      value: p.uid,
                      child: Text(p.fullName.isNotEmpty ? p.fullName : "Sem nome"),
                    );
                  }).toList(),
                  onChanged: (val) => dialogSetState(() => selectedFuncionarioId = val),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                final bool tituloOk = titleCtrl.text.isNotEmpty;
                final bool podeCriar = criarParaTodos ? tituloOk : (tituloOk && selectedFuncionarioId != null);
                if (!podeCriar) return;

                final adminUser = FirebaseAuth.instance.currentUser;
                final String? creatorUid = adminUser?.uid;

                // Busca o nome real do criador no Firestore
                String creatorName = 'Administrador';
                if (creatorUid != null) {
                  final creatorPerson = await PeopleService.fetchPerson(creatorUid);
                  if (creatorPerson != null && creatorPerson.fullName.isNotEmpty) {
                    creatorName = creatorPerson.fullName;
                  }
                }

                Map<String, dynamic> taskData = {
                  'title': titleCtrl.text,
                  'observacoes': obsCtrl.text,
                  'deadline': "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                  'urgencia': selectedUrgencia,
                  'status': 0, // Não Lido
                  'createdBy': creatorUid,
                  'createdByName': creatorName,
                  'createdAt': FieldValue.serverTimestamp(),
                };

                if (criarParaTodos) {
                  // Inclui TODOS (funcionarios + users), exceto o próprio criador
                  final todos = pessoas
                      .where((p) => p.uid != adminUser?.uid)
                      .toList();

                  final List<String> allUids = todos.map((p) => p.uid).toList();

                  // Cria UM único documento na coleção tasks
                  DocumentReference taskRef = FirebaseFirestore.instance.collection('tasks').doc();
                  final dataComDestino = {
                    ...taskData,
                    'paraTodos': true,
                    'assignedTo': 'todos',
                    'assignedToAll': allUids,
                  };

                  WriteBatch batch = FirebaseFirestore.instance.batch();
                  batch.set(taskRef, dataComDestino);

                  // Replica nas subcoleções de cada pessoa
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
                  DocumentReference taskRef = FirebaseFirestore.instance.collection('tasks').doc();
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
              child: const Text("Criar"),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog para editar uma tarefa já existente.
  Future<void> _showEditTaskDialog(String taskId, Map<String, dynamic> data) async {
    TextEditingController titleCtrl = TextEditingController(text: data['title'] ?? '');
    TextEditingController obsCtrl = TextEditingController(text: data['observacoes'] ?? '');

    DateTime selectedDate = DateTime.now();
    final String? deadlineStr = data['deadline'] as String?;
    if (deadlineStr != null && deadlineStr.contains('/')) {
      final parts = deadlineStr.split('/');
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) {
          selectedDate = DateTime(y, m, d);
        }
      }
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
          title: const Text("Editar Tarefa"),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Título da Tarefa")),
              TextField(controller: obsCtrl, decoration: const InputDecoration(labelText: "Observações"), maxLines: 2),

              ListTile(
                title: Text("Data Limite: ${"${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"}"),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    dialogSetState(() => selectedDate = picked);
                  }
                },
              ),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Nível de Urgência:"),
                initialValue: selectedUrgencia,
                items: urgenciaOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (val) => dialogSetState(() => selectedUrgencia = val!),
              ),

              // Não permite trocar atribuição de tarefa "para todos"
              if (!isParaTodos)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Atribuir para:"),
                  initialValue: selectedFuncionarioId,
                  items: pessoas.map((p) {
                    return DropdownMenuItem(
                      value: p.uid,
                      child: Text(p.fullName.isNotEmpty ? p.fullName : "Sem nome"),
                    );
                  }).toList(),
                  onChanged: (val) => dialogSetState(() => selectedFuncionarioId = val),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                if (!isParaTodos && selectedFuncionarioId == null) return;

                final Map<String, dynamic> updatedData = {
                  ...data,
                  'title': titleCtrl.text,
                  'observacoes': obsCtrl.text,
                  'deadline': "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                  'urgencia': selectedUrgencia,
                };
                if (!isParaTodos) {
                  updatedData['assignedTo'] = selectedFuncionarioId;
                }

                WriteBatch batch = FirebaseFirestore.instance.batch();
                DocumentReference taskRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
                batch.update(taskRef, updatedData);

                if (isParaTodos) {
                  // Atualiza em todas as subcoleções
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
                  if (oldFuncionarioId != null && oldFuncionarioId != selectedFuncionarioId) {
                    final oldRef = FirebaseFirestore.instance
                        .collection('funcionarios')
                        .doc(oldFuncionarioId)
                        .collection('tarefas')
                        .doc(taskId);
                    batch.delete(oldRef);
                    final oldRefUser = FirebaseFirestore.instance
                        .collection('users')
                        .doc(oldFuncionarioId)
                        .collection('tarefas')
                        .doc(taskId);
                    batch.delete(oldRefUser);

                    final newRef = FirebaseFirestore.instance
                        .collection('funcionarios')
                        .doc(selectedFuncionarioId)
                        .collection('tarefas')
                        .doc(taskId);
                    batch.set(newRef, updatedData);
                    final newRefUser = FirebaseFirestore.instance
                        .collection('users')
                        .doc(selectedFuncionarioId)
                        .collection('tarefas')
                        .doc(taskId);
                    batch.set(newRefUser, updatedData);
                  } else {
                    final sameRef = FirebaseFirestore.instance
                        .collection('funcionarios')
                        .doc(selectedFuncionarioId)
                        .collection('tarefas')
                        .doc(taskId);
                    batch.set(sameRef, updatedData, SetOptions(merge: true));
                    final sameRefUser = FirebaseFirestore.instance
                        .collection('users')
                        .doc(selectedFuncionarioId)
                        .collection('tarefas')
                        .doc(taskId);
                    batch.set(sameRefUser, updatedData, SetOptions(merge: true));
                  }
                }

                await batch.commit();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text("Salvar"),
            ),
          ],
        ),
      ),
    );
  }

  // Busca os dados (nome + foto) de quem criou a tarefa
  Future<Person?> _getSenderPerson(String? createdBy) async {
    if (createdBy == null || createdBy.isEmpty) return null;
    return PeopleService.fetchPerson(createdBy);
  }

  Widget _senderAvatar(Person? person, {double radius = 13}) {
    final fotoUrl = person?.fotoUrl ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.black12,
      backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
      child: fotoUrl.isEmpty
          ? Icon(Icons.person, size: radius, color: Colors.black54)
          : null,
    );
  }

  /// Formata o Timestamp do Firestore para dd/mm/aaaa
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

  // Dialog somente leitura com os detalhes completos da tarefa.
  // Ao abrir, se o status for 0 (Não Lido) e o usuário for o destinatário,
  // marca automaticamente como "Lido" (status 1).
  void _showTaskDetailsDialog(String taskId, Map<String, dynamic> data, bool canEdit) {
    final int status = data['status'] ?? 0;
    final bool recipient = _isRecipient(data);
    final bool isFinalizada = status == 3;

    // Marca como LIDO automaticamente ao abrir (status 0 → 1)
    if (recipient && status == 0) {
      _updateTaskStatus(taskId, data, 1);
    }

    final String criadoEm = _formatCreatedAt(data['createdAt']);
    final bool isParaTodos = data['paraTodos'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text((data['title'] ?? 'Tarefa').toString()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Observações:", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text((data['observacoes'] ?? '—').toString()),
              const SizedBox(height: 10),
              Text("Prazo: ${data['deadline'] ?? '--/--/--'}"),
              Text("Urgência: ${data['urgencia'] ?? '—'}"),
              if (isParaTodos)
                const Text("Atribuído para: Todos")
              else
                Text("Atribuído para: ${data['assignedTo'] ?? '—'}"),
              Text("Criado por: ${data['createdByName'] ?? '—'}"),
              if (criadoEm.isNotEmpty) Text("Criado em: $criadoEm"),
            ],
          ),
        ),
        actions: [
          if (recipient && !isFinalizada && (status == 0 || status == 1))
            TextButton(
              onPressed: () {
                _updateTaskStatus(taskId, data, 2); // Em Processo
                Navigator.pop(ctx);
              },
              child: const Text("MARCAR EM PROCESSO"),
            ),
          if (recipient && !isFinalizada)
            TextButton(
              onPressed: () {
                _updateTaskStatus(taskId, data, 3); // Finalizado
                Navigator.pop(ctx);
              },
              child: const Text("FINALIZAR", style: TextStyle(color: Colors.green)),
            ),
          if (canEdit)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showEditTaskDialog(taskId, data);
              },
              child: const Text("EDITAR"),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FECHAR")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GESTÃO DE TAREFAS"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(text: "TAREFAS ATRIBUÍDAS A MIM"),
            Tab(text: "ATRIBUÍDAS POR MIM"),
            Tab(text: "HISTÓRICO"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTaskDialog,
        backgroundColor: const Color(0xFFD4AF37),
        child: const Icon(Icons.add, color: Colors.white),
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
              // Para tarefas "para todos", mostra 1 card (não filtra por assignedTo)
              if (isParaTodos) return true;
              return data['assignedTo'] != _currentUid;

            case _TaskFilter.history:
              if (!isFinalizada) return false;
              if (isAdmin) return true;
              // Não-admin: vê histórico próprio
              if (isParaTodos) {
                final all = data['assignedToAll'];
                if (all is List && all.contains(_currentUid)) return true;
              }
              return data['assignedTo'] == _currentUid || data['createdBy'] == _currentUid;
          }
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  filter == _TaskFilter.history ? Icons.history : Icons.task_alt,
                  size: 60,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  filter == _TaskFilter.history
                      ? "Nenhuma tarefa no histórico."
                      : "Nenhuma tarefa por aqui.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
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
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 7,
            mainAxisSpacing: 16,
            childAspectRatio: 0.65,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            int status = data['status'] ?? 0;
            final bool canEdit = data['createdBy'] == _currentUid && status != 3;
            final bool isParaTodos = data['paraTodos'] == true;

            // Cores e labels por status
            Color color;
            String label;
            switch (status) {
              case 0:
                color = Colors.redAccent;
                label = "NÃO LIDO";
                break;
              case 1:
                color = Colors.blueAccent;
                label = "LIDO";
                break;
              case 2:
                color = Colors.amber;
                label = "EM PROCESSO";
                break;
              case 3:
                color = Colors.green;
                label = "FINALIZADO";
                break;
              default:
                color = Colors.grey;
                label = "—";
            }

            final String criadoEm = _formatCreatedAt(data['createdAt']);

            return InkWell(
              onTap: () => _showTaskDetailsDialog(doc.id, data, canEdit),
              child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  )
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(15),
                  bottomLeft: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + avatar de quem criou + botão de editar
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (data['title'] ?? '').toString().toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      FutureBuilder<Person?>(
                        future: _getSenderPerson(data['createdBy']?.toString()),
                        builder: (context, snap) {
                          return _senderAvatar(snap.data, radius: 12);
                        },
                      ),
                      if (canEdit)
                        InkWell(
                          onTap: () => _showEditTaskDialog(doc.id, data),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.edit, size: 14, color: Colors.black54),
                          ),
                        ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 4),
                  // Observações
                  Expanded(
                    child: Text(
                      (data['observacoes'] ?? '').toString().toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: Colors.black),
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  const Divider(color: Colors.black12),
                  // Rodapé: criado por + data
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      "${data['createdByName'] ?? '—'} ${criadoEm.isNotEmpty ? '• $criadoEm' : ''}",
                      style: const TextStyle(fontSize: 9, color: Colors.black54, fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Rodapé com Data Limite, botão excluir e status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['deadline'] ?? '--/--/--',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (canEdit)
                        Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Excluir Tarefa"),
                                  content: const Text("Tem certeza que deseja remover esta tarefa?"),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Não")),
                                    TextButton(
                                      onPressed: () {
                                        _deleteTask(doc.id, data);
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text("Sim, excluir", style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                          ),
                        ),

                      // Badge "TODOS" para tarefas globais
                      if (isParaTodos)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text("TODOS", style: TextStyle(color: Colors.purple, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
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