import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/people_service.dart';
import '../../core/theme.dart';
import '../../core/user_session.dart';
import 'chat.dart';
import 'new_chat_screen.dart';

class MensagensScreen extends StatelessWidget {
  const MensagensScreen({super.key});

  void _openNewChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isAdmin = UserSession.isAdmin();

    return Scaffold(
      backgroundColor: inkPageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(34, 30, 34, 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Conversas",
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontWeight: FontWeight.w500,
                      fontSize: 27,
                      color: dellalioTitle,
                    ),
                  ),
                ),
                _NewChatButton(onTap: () => _openNewChat(context)),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildChatStream(myUid, isAdmin),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildFallbackFilteredByParticipant(
                    context,
                    myUid,
                    isAdmin,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: dellalioGold),
                  );
                }
                final docs = _filterValidChats(
                  snapshot.data!.docs,
                  myUid,
                  isAdmin,
                );
                return _buildList(context, docs, myUid);
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot>? _buildChatStream(String? myUid, bool isAdmin) {
    if (myUid == null && !isAdmin) return null;

    if (isAdmin) {
      return FirebaseFirestore.instance
          .collection('chats')
          .orderBy('lastMessageAt', descending: true)
          .snapshots();
    }

    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterValidChats(
    List<QueryDocumentSnapshot> docs,
    String? myUid,
    bool isAdmin,
  ) {
    if (isAdmin) return docs;
    if (myUid == null) return [];
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      final participants = data['participants'];
      if (participants is! List) return false;
      return participants.contains(myUid);
    }).toList();
  }

  Widget _buildFallbackFilteredByParticipant(
    BuildContext context,
    String? myUid,
    bool isAdmin,
  ) {
    if (myUid == null && !isAdmin) {
      return Center(
        child: Text(
          "Nenhuma conversa ainda.",
          style: TextStyle(color: panelSlate),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: isAdmin
          ? FirebaseFirestore.instance.collection('chats').snapshots()
          : FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: myUid)
                .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: dellalioGold),
          );
        }
        final docs = _filterValidChats(snapshot.data!.docs, myUid, isAdmin);
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTs = aData['lastMessageAt'] as Timestamp?;
          final bTs = bData['lastMessageAt'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });
        return _buildList(context, docs, myUid);
      },
    );
  }

  Future<void> _deleteChat(
    BuildContext context,
    String chatId,
    String title, {
    required bool isGroup,
  }) async {
    if (isGroup && !UserSession.isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Apenas o administrador pode excluir uma conversa em grupo.",
          ),
          backgroundColor: panelRust,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: inkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text("Excluir conversa", style: TextStyle(color: panelIvory)),
        content: Text(
          'Tem certeza que deseja excluir "$title"? Todas as mensagens serão apagadas permanentemente.',
          style: TextStyle(color: panelSlate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancelar", style: TextStyle(color: panelSlate)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Excluir", style: TextStyle(color: panelRust)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId);
      final messagesSnap = await chatRef.collection('messages').get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (final doc in messagesSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(chatRef);
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Conversa excluída com sucesso!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erro ao excluir conversa: $e")));
      }
    }
  }

  Widget _buildList(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
    String? myUid,
  ) {
    if (docs.isEmpty) {
      return Center(
        child: Text(
          "Nenhuma conversa ainda.",
          style: TextStyle(color: panelSlate),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final chat = docs[index];
        final data = chat.data() as Map<String, dynamic>;
        final type = (data['type'] ?? 'group').toString();
        final name = (data['name'] ?? 'Chat').toString();
        final lastMessage = (data['lastMessage'] ?? '').toString();
        final participants = List<String>.from(data['participants'] ?? []);

        if (type == 'individual' && myUid != null) {
          final otherUid = participants.firstWhere(
            (p) => p != myUid,
            orElse: () => '',
          );
          if (otherUid.isNotEmpty) {
            return FutureBuilder<Person?>(
              future: PeopleService.fetchPerson(otherUid),
              builder: (context, personSnap) {
                final person = personSnap.data;
                final displayName = person?.fullName.isNotEmpty == true
                    ? person!.fullName
                    : name;
                return _ChatRow(
                  chatId: chat.id,
                  title: displayName,
                  subtitle: lastMessage,
                  photoUrl: person?.fotoUrl ?? '',
                  isGroup: false,
                  delayIndex: index % 14,
                  onDelete: () => _deleteChat(
                    context,
                    chat.id,
                    displayName,
                    isGroup: false,
                  ),
                );
              },
            );
          }
        }

        return _ChatRow(
          chatId: chat.id,
          title: name,
          subtitle: lastMessage,
          photoUrl: '',
          isGroup: true,
          delayIndex: index % 14,
          onDelete: () => _deleteChat(context, chat.id, name, isGroup: true),
        );
      },
    );
  }
}

class _NewChatButton extends StatefulWidget {
  final VoidCallback onTap;
  const _NewChatButton({required this.onTap});

  @override
  State<_NewChatButton> createState() => _NewChatButtonState();
}

class _NewChatButtonState extends State<_NewChatButton> {
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
          duration: const Duration(milliseconds: 160),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover ? dellalioGoldSoft : dellalioGold,
          ),
          child: Icon(Icons.add, color: inkPageBg, size: 18),
        ),
      ),
    );
  }
}

class _ChatRow extends StatefulWidget {
  final String chatId;
  final String title;
  final String subtitle;
  final String photoUrl;
  final bool isGroup;
  final int delayIndex;
  final VoidCallback onDelete;

  const _ChatRow({
    required this.chatId,
    required this.title,
    required this.subtitle,
    required this.photoUrl,
    required this.isGroup,
    required this.delayIndex,
    required this.onDelete,
  });

  @override
  State<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends State<_ChatRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool canDelete = !widget.isGroup || UserSession.isAdmin();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChatScreen(chatId: widget.chatId, chatName: widget.title),
          ),
        ),
        onLongPress: widget.onDelete,
        child:
            AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _hover ? inkSurface : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: inkSurfaceHover,
                        backgroundImage: widget.photoUrl.isNotEmpty
                            ? NetworkImage(widget.photoUrl)
                            : null,
                        child: (widget.isGroup || widget.photoUrl.isEmpty)
                            ? Icon(
                                widget.isGroup
                                    ? Icons.forum_outlined
                                    : Icons.person_outline,
                                size: 17,
                                color: panelSlate,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: panelIvory,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: panelSlate,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canDelete && _hover)
                        GestureDetector(
                          onTap: widget.onDelete,
                          child: Icon(
                            Icons.delete_outline,
                            size: 17,
                            color: panelRust,
                          ),
                        ),
                    ],
                  ),
                )
                .animate(delay: (40 * widget.delayIndex).ms)
                .fadeIn(duration: 350.ms)
                .slideX(begin: -0.03, end: 0, curve: Curves.easeOut),
      ),
    );
  }
}
