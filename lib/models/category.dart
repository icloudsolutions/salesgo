import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String name;
  final DocumentReference? reference; // Add reference field
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.reference,
    required this.createdAt,
  });

  factory Category.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id,
      name: data['name'] ?? '',
      reference: doc.reference,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    //'imageUrl': imageUrl,
    'createdAt': FieldValue.serverTimestamp(),
  };
}