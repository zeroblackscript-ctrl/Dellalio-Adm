import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat.dart';
import 'new_chat_screen.dart';
import '../../core/people_service.dart';
import '../../core/user_session.dart';


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

    return Scaffold(
      appBar: AppBar(title: const Text("Conversas")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNewChat(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: myUid != null
            ? FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: myUid)
                .orderBy('lastMessageAt', descending: true)
                .snapshots()
            : null,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildFallbackFilteredByParticipant(context, myUid);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = _filterValidChats(snapshot.data!.docs, myUid);
          return _buildList(context, docs, myUid);
        },
      ),
    );
  }

  /// Filtra apenas os chats onde o [myUid] está realmente presente no campo
  /// `participants`. Isso é uma camada extra de segurança para o caso de
  /// existirem documentos no banco com o campo `participants` inconsistente
  /// ou nulo, garantindo que conversas de outros usuários não sejam expostas.
  List<QueryDocumentSnapshot> _filterValidChats(
    List<QueryDocumentSnapshot> docs,
    String? myUid,
  ) {
    if (myUid == null) return [];
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      final participants = data['participants'];
      if (participants is! List) return false;
      return participants.contains(myUid);
    }).toList();
  }

  // Fallback SEGURO: ainda filtra por participants (arrayContains), apenas
  // sem o orderBy, evitando expor conversas de outros usuários caso o
  // índice composto não exista.
  Widget _buildFallbackFilteredByParticipant(BuildContext context, String? myUid) {
    if (myUid == null) {
      return const Center(child: Text("Nenhuma conversa ainda."));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: myUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = _filterValidChats(snapshot.data!.docs, myUid);
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

  Future<void> _deleteChat(BuildContext context, String chatId, String title, {required bool isGroup}) async {
    // Grupos só podem ser excluídos pelo administrador. Chats individuais
    // continuam podendo ser excluídos por qualquer um dos participantes.
    if (isGroup && !UserSession.isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Apenas o administrador pode excluir uma conversa em grupo."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Conversa"),
        content: Text('Tem certeza que deseja excluir "$title"? Todas as mensagens serão apagadas permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("EXCLUIR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );


    if (confirm != true) return;

    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao excluir conversa: $e")),
        );
      }
    }
  }

  Widget _buildList(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
    String? myUid,
  ) {
    if (docs.isEmpty) {
      return const Center(child: Text("Nenhuma conversa ainda."));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                return _buildChatCard(
                  context,
                  chatId: chat.id,
                  title: displayName,
                  subtitle: lastMessage,
                  photoUrl: person?.fotoUrl ?? '',
                  isGroup: false,
                );
              },
            );
          }
        }

        return _buildChatCard(
          context,
          chatId: chat.id,
          title: name,
          subtitle: lastMessage,
          photoUrl: '',
          isGroup: true,
        );
      },
    );
  }

  Widget _buildChatCard(
    BuildContext context, {
    required String chatId,
    required String title,
    required String subtitle,
    required String photoUrl,
    required bool isGroup,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, chatName: title),
        ),
      ),
      onLongPress: () => _deleteChat(context, chatId, title, isGroup: isGroup),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black87, width: 2.0),

          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(5),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(5),
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black87, offset: Offset(3, 3)),
          ],
        ),
        child: Row(
          children: [
            isGroup
                ? const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.black12,
                    child: Icon(Icons.forum, color: Colors.black87),
                  )
                : CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.black12,
                    backgroundImage:
                        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.black45)
                        : null,
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (!isGroup || UserSession.isAdmin())
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                tooltip: 'Excluir conversa',
                onPressed: () => _deleteChat(context, chatId, title, isGroup: isGroup),
              ),

          ],
        ),
      ),
    );
  }
}