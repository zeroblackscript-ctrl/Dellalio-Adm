import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/people_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId, chatName;
  const ChatScreen({super.key, required this.chatId, required this.chatName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Cache local para não buscar repetidamente a foto do mesmo remetente
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

    // 1. Busca o nome/foto real do usuário (users ou funcionarios)
    final person = await PeopleService.fetchPerson(user.uid);
    String userName = person?.fullName.isNotEmpty == true
        ? person!.fullName
        : "Usuário";
    String userPhoto = person?.fotoUrl ?? '';

    // 2. Prepara o lote de escrita (Batch) para salvar nos locais necessários
    WriteBatch batch = FirebaseFirestore.instance.batch();

    // Local A: Mensagem no Chat
    DocumentReference chatMsgRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(); // Gera um ID automático

    batch.set(chatMsgRef, {
      'text': text,
      'imageUrl': imageUrl,
      'senderId': user.uid,
      'senderName': userName, // Salva o nome vindo do Firestore
      'senderPhoto': userPhoto,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Local B: Atualiza a prévia da última mensagem no chat (para a lista)
    DocumentReference chatRef =
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    batch.set(chatRef, {
      'lastMessage': text ?? (imageUrl != null ? '📷 Imagem' : ''),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Local C: Histórico no perfil do usuário (se existir a coleção correta)
    final logCollection = person?.origem == 'funcionarios'
        ? 'funcionarios'
        : 'users';
    DocumentReference userLogRef = FirebaseFirestore.instance
        .collection(logCollection)
        .doc(user.uid)
        .collection('mensagens_enviadas')
        .doc(); // Cria um registro no histórico do usuário

    batch.set(userLogRef, {
      'chatId': widget.chatId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Executa tudo
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

  Widget _avatar(String photoUrl, {double radius = 16}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.black12,
      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl.isEmpty
          ? Icon(Icons.person, size: radius, color: Colors.black45)
          : null,
    );
  }

  void _markAsRead() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .set({
      'lastRead.${user.uid}': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Marca o chat como lido ao abrir a tela
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());

    return Scaffold(
      appBar: AppBar(title: Text(widget.chatName)),
      body: Column(
        children: [
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
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var msg = snapshot.data!.docs[index];
                    var data = msg.data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == user?.uid;
                    String storedPhoto = (data['senderPhoto'] ?? '')
                        .toString();

                    Widget buildBubble(String photoUrl) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              _avatar(photoUrl),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.amber.shade200
                                      : Colors.blueGrey.shade100,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: isMe
                                        ? const Radius.circular(20)
                                        : Radius.zero,
                                    bottomRight: isMe
                                        ? Radius.zero
                                        : const Radius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Text(
                                        data['senderName'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    if (data['text'] != null)
                                      Text(data['text']),
                                    if (data['imageUrl'] != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          8,
                                        ),
                                        child: Image.network(
                                          data['imageUrl'],
                                          width: 150,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              _avatar(photoUrl),
                            ],
                          ],
                        ),
                      );
                    }

                    // Se a mensagem já tem a foto salva, usa direto.
                    if (storedPhoto.isNotEmpty) {
                      return buildBubble(storedPhoto);
                    }

                    // Caso contrário (mensagens antigas), busca no serviço
                    // unificado de pessoas para exibir a foto correta.
                    final senderId = (data['senderId'] ?? '').toString();
                    return FutureBuilder<Person?>(
                      future: senderId.isEmpty
                          ? null
                          : _getSenderPerson(senderId),
                      builder: (context, snap) {
                        return buildBubble(snap.data?.fotoUrl ?? '');
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _pickAndUpload,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _sendMessage(text: value);
                      }
                    },
                    decoration: const InputDecoration(hintText: "Digite..."),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(text: _msgCtrl.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
