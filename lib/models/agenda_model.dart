import 'package:cloud_firestore/cloud_firestore.dart';

class AgendaEvent {
  final String id;
  final String userId;
  final String userName;
  final String userColor; // Ex: "#FF5733"
  final String description;
  final DateTime date;

  AgendaEvent({
    required this.id, 
    required this.userId, 
    required this.userName, 
    required this.userColor, 
    required this.description, 
    required this.date
  });

  factory AgendaEvent.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return AgendaEvent(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userColor: data['userColor'] ?? '#000000',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
    );
  }
}