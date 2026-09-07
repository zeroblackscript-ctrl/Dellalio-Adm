import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/people_service.dart';
import '../../core/theme.dart';

class ChatScreen extends StatefulWidget {
  final String chatId, chatName;
  const ChatScreen({super.key, required this.chatId, required this.chatName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final Map<String, Person?> _personCache = {};

  Future<Person?> _getSenderPerson(String senderId) async {
    if (_personCache.containsKey(senderId)) return _personCache[senderId];
    final person = await PeopleService.fetchPerson(senderId);
    _personCache[senderId] = person;
    return person;
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final person = await PeopleService.fetchPerson(user.uid);
    String userName = person?.fullName.isNotEmpty == true
        ? person!.fullName
        : "Usuário";
    String userPhoto = person?.fotoUrl ?? '';

    WriteBatch batch = FirebaseFirestore.instance.batch();

    DocumentReference chatMsgRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc();

    batch.set(chatMsgRef, {
      'text': text,
      'imageUrl': imageUrl,
      'senderId': user.uid,
      'senderName': userName,
      'senderPhoto': userPhoto,
      'createdAt': FieldValue.serverTimestamp(),
    });

    DocumentReference chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId);
    batch.set(chatRef, {
      'lastMessage': text ?? (imageUrl != null ? '📷 Imagem' : ''),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final logCollection = person?.origem == 'funcionarios'
        ? 'funcionarios'
        : 'users';
    DocumentReference userLogRef = FirebaseFirestore.instance
        .collection(logCollection)
        .doc(user.uid)
        .collection('mensagens_enviadas')
        .doc();

    batch.set(userLogRef, {
      'chatId': widget.chatId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    if (!mounted) return;
    _msgCtrl.clear();
  }

  Future<void> _pickAndUpload() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference ref = FirebaseStorage.instance.ref().child(
      'chat_images/$fileName',
    );
    await ref.putFile(File(file.path));
    String url = await ref.getDownloadURL();
    _sendMessage(imageUrl: url);
  }

  void _markAsRead() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
      'lastRead.${user.uid}': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());

    return Scaffold(
      backgroundColor: inkPageBg,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: hairline)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back, size: 20, color: panelSlate),
                ),
                const SizedBox(width: 14),
                CircleAvatar(
                  radius: 17,
                  backgroundColor: inkSurfaceHover,
                  child: Icon(
                    Icons.person_outline,
                    size: 16,
                    color: panelSlate,
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  widget.chatName,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: panelIvory,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: dellalioGold),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var msg = snapshot.data!.docs[index];
                    var data = msg.data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == user?.uid;
                    String storedPhoto = (data['senderPhoto'] ?? '').toString();

                    Widget buildBubble(String photoUrl) {
                      return _MessageBubble(
                        isMe: isMe,
                        photoUrl: photoUrl,
                        senderName: data['senderName'] ?? '',
                        text: data['text'],
                        imageUrl: data['imageUrl'],
                      );
                    }

                    if (storedPhoto.isNotEmpty) return buildBubble(storedPhoto);

                    final senderId = (data['senderId'] ?? '').toString();
                    return FutureBuilder<Person?>(
                      future: senderId.isEmpty
                          ? null
                          : _getSenderPerson(senderId),
                      builder: (context, snap) =>
                          buildBubble(snap.data?.fotoUrl ?? ''),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: hairline)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickAndUpload,
                  child: Icon(
                    Icons.image_outlined,
                    size: 21,
                    color: panelSlate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: inkSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: hairline),
                    ),
                    child: TextField(
                      controller: _msgCtrl,
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) _sendMessage(text: value);
                      },
                      style: TextStyle(color: panelIvory, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: "Escreva uma mensagem...",
                        hintStyle: TextStyle(
                          color: panelSlateDim,
                          fontSize: 13.5,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _sendMessage(text: _msgCtrl.text),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: dellalioGold,
                    ),
                    child: Icon(Icons.send, size: 16, color: inkPageBg),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final bool isMe;
  final String photoUrl;
  final String senderName;
  final String? text;
  final String? imageUrl;

  const _MessageBubble({
    required this.isMe,
    required this.photoUrl,
    required this.senderName,
    this.text,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: inkSurfaceHover,
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl.isEmpty
                      ? Icon(Icons.person, size: 14, color: panelSlate)
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? dellalioGold.withValues(alpha: 0.14)
                        : inkSurface,
                    border: Border.all(
                      color: isMe
                          ? dellalioGold.withValues(alpha: 0.3)
                          : hairline,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMe ? 14 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe && senderName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            senderName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              color: dellalioGoldSoft,
                            ),
                          ),
                        ),
                      if (text != null)
                        Text(
                          text!,
                          style: TextStyle(color: panelIvory, fontSize: 13),
                        ),
                      if (imageUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(imageUrl!, width: 150),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: inkSurfaceHover,
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl.isEmpty
                      ? Icon(Icons.person, size: 14, color: panelSlate)
                      : null,
                ),
              ],
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 260.ms)
        .slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
  }
}
