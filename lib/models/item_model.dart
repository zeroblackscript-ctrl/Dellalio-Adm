class ItemModel {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final int minQuantity;
  final String imageUrl; // Novo campo para a foto

  ItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.minQuantity,
    required this.imageUrl,
  });

  // Converte para Map (para salvar no Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'minQuantity': minQuantity,
      'imageUrl': imageUrl,
    };
  }

  // Converte de Map (para ler do Firestore)
  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      quantity: map['quantity'] ?? 0,
      minQuantity: map['minQuantity'] ?? 0,
      imageUrl: map['imageUrl'] ?? '',
    );
  }
}
