class ClientModel {
  final String id;
  final String name;
  final String address;
  final List<String> pdfUrls; // Lista de URLs
  final String notes;
  final DateTime createdAt;

  ClientModel({
    required this.id,
    required this.name,
    required this.address,
    required this.pdfUrls,
    required this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'pdfUrls': pdfUrls,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
