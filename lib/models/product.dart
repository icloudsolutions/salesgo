import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final String barcode;
  final String? imageUrl;
  final List<String> availableLocations;

  

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.barcode,
    this.imageUrl,
    this.availableLocations = const [],

  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Product(
      id: doc.id,
      name: data['name'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] as String? ?? '',
      barcode: data['barcode'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      availableLocations: List<String>.from(data['availableLocations'] ?? []),

    );
  }

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      
    );
  }
  
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'category': category,
    'barcode': barcode,
    'imageUrl': imageUrl, 
    'availableLocations': availableLocations,

  };
}