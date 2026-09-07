import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/dellalio_kit.dart';
import '../../core/people_service.dart';
import '../../core/theme.dart';
import 'chat.dart';

/// Tela para criação de uma nova conversa, permitindo escolher entre
/// um Grupo (nome customizado, pode ter vários participantes) ou
/// um chat Individual (1 para 1) com outra pessoa (admin ou funcionário).
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _groupNameCtrl = TextEditingController();

  List<Person> _people = [];
  bool _loadingPeople = true;
  final Set<String> _selectedForGroup = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final people = await PeopleService.fetchAllPeople(excludeUid: uid);
    if (!mounted) return;
    setState(() {
      _people = people;
      _loadingPeople = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  bool _creatingGroup = false;

  Future<void> _createGroupChat() async {
    final name = _groupNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um nome para o grupo.')),
      );
      return;
    }

    if (_creatingGroup) return;
    setState(() => _creatingGroup = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final participants =
          {..._selectedForGroup, if (uid != null) uid}.toList();

      final docRef = await FirebaseFirestore.instance.collection('chats').add({
        'name': name,
        'type': 'group',
        'participants': participants,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: docRef.id, chatName: name),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar grupo: $e')),
      );
    } finally {
      if (mounted) setState(() => _creatingGroup = false);
    }
  }


  Future<void> _openOrCreateIndividualChat(Person other) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final myUid = currentUser.uid;

    // Verifica se já existe uma conversa individual entre essas duas pessoas
    final query = await FirebaseFirestore.instance
        .collection('chats')
        .where('type', isEqualTo: 'individual')
        .where('participants', arrayContains: myUid)
        .get();

    QueryDocumentSnapshot? existing;
    for (final doc in query.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);

      if (participants.contains(other.uid) && participants.length == 2) {
        existing = doc;
        break;
      }
    }

    String chatId;
    String chatName = other.fullName.isEmpty ? 'Conversa' : other.fullName;

    if (existing != null) {
      chatId = existing.id;
    } else {
      final docRef = await FirebaseFirestore.instance.collection('chats').add({
        'name': chatName,
        'type': 'individual',
        'participants': [myUid, other.uid],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      chatId = docRef.id;
    }

    if (!mounted) return;
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chatId, chatName: chatName),
      ),
    );
  }

  Widget _personAvatar(Person p, {double radius = 20}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: inkSurfaceHover,
      backgroundImage: p.fotoUrl.isNotEmpty ? NetworkImage(p.fotoUrl) : null,
      child: p.fotoUrl.isEmpty
          ? Icon(Icons.person, size: radius, color: panelSlate)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inkPageBg,
      body: Column(
        children: [
          const DellalioSubHeader(title: "Nova conversa"),
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: hairline)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: dellalioGold,
              labelColor: panelIvory,
              unselectedLabelColor: panelSlate,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: "Grupo", icon: Icon(Icons.groups)),
                Tab(text: "Individual", icon: Icon(Icons.person)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGroupTab(),
                _buildIndividualTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DellalioFormField(
            controller: _groupNameCtrl,
            label: "Nome do grupo",
            icon: Icons.group_outlined,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Participantes (opcional):",
              style: TextStyle(fontWeight: FontWeight.w600, color: panelSlate),
            ),
          ),
        ),
        Expanded(
          child: _loadingPeople
              ? const Center(child: CircularProgressIndicator(color: dellalioGold))
              : ListView.builder(
                  itemCount: _people.length,
                  itemBuilder: (context, index) {
                    final p = _people[index];
                    final selected = _selectedForGroup.contains(p.uid);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? dellalioGold.withValues(alpha: 0.08)
                            : inkSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? dellalioGold : hairline,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: selected,
                        activeColor: dellalioGold,
                        checkColor: inkPageBg,
                        secondary: _personAvatar(p),
                        title: Text(p.fullName.isEmpty ? p.uid : p.fullName,
                            style: TextStyle(color: panelIvory, fontSize: 14)),
                        subtitle: Text(p.role.toUpperCase(),
                            style: TextStyle(color: panelSlateDim, fontSize: 11)),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedForGroup.add(p.uid);
                            } else {
                              _selectedForGroup.remove(p.uid);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DellalioGoldButton(
            label: "Criar grupo",
            icon: Icons.group_add_outlined,
            fullWidth: true,
            onPressed: _createGroupChat,
          ),
        ),
      ],
    );
  }

  Widget _buildIndividualTab() {
    if (_loadingPeople) {
      return const Center(child: CircularProgressIndicator(color: dellalioGold));
    }
    if (_people.isEmpty) {
      return const DellalioEmptyState(
        icon: Icons.person_search_outlined,
        title: "Nenhuma pessoa encontrada",
      );
    }
    return ListView.builder(
      itemCount: _people.length,
      itemBuilder: (context, index) {
        final p = _people[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: inkSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: hairline),
          ),
          child: ListTile(
            leading: _personAvatar(p),
            title: Text(p.fullName.isEmpty ? p.uid : p.fullName,
                style: TextStyle(color: panelIvory, fontSize: 14)),
            subtitle: Text(p.role.toUpperCase(),
                style: TextStyle(color: panelSlateDim, fontSize: 11)),
            onTap: () => _openOrCreateIndividualChat(p),
          ),
        );
      },
    );
  }
}
