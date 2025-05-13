import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final DocumentReference categoryRef;
  final String barcode;
  final String? imageUrl;
  final List<String> availableLocations;
  final DocumentReference? reference;
  //final DateTime createdAt;

 

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryRef,
    required this.barcode,
    this.imageUrl,
    this.availableLocations = const [],
    this.reference,
    //required this.createdAt,

  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Product(
      id: doc.id,
      name: data['name'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      categoryRef: data['categoryRef'] as DocumentReference,
      barcode: data['barcode'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      availableLocations: List<String>.from(data['availableLocations'] ?? []),
      //createdAt:  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),

    );
  }

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      categoryRef: map['categoryRef'] as DocumentReference, 
      barcode: map['barcode'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      //createdAt: (map['createdAt'] as Timestamp?)!.toDate(),
      
    );
  }
  
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'categoryRef': categoryRef,
    'barcode': barcode,
    'imageUrl': imageUrl, 
    'availableLocations': availableLocations,
    //'createdAt': FieldValue.serverTimestamp(),

  };

  // Add barcode validation method
  static String? validateBarcode(String? value) {
    if (value == null || value.isEmpty) return 'Barcode is required';
    if (value.length < 3) return 'Barcode too short (min 3 chars)';
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
      return 'Only alphanumeric characters allowed';
    }
    return null;
  }

}