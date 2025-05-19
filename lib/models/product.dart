import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final DocumentReference categoryRef;
  final String barcode;
  final String? imageUrl;
  final List<String> availableLocations;
  final double stockQuantity;
  final double minStockLevel;
  final bool trackStock;
  final bool isDeleted;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryRef,
    required this.barcode,
    this.imageUrl,
    this.availableLocations = const [],
    this.stockQuantity = 0,
    this.minStockLevel = 0,
    this.trackStock = false,
    this.isDeleted = false,
    Timestamp? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  bool get needsRestock => trackStock && stockQuantity <= minStockLevel;
  bool get isOutOfStock => trackStock && stockQuantity <= 0;

  factory Product.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return Product(
        id: doc.id,
        name: data['name']?.toString() ?? '',
        price: _parseDouble(data['price']),
        categoryRef: data['categoryRef'] as DocumentReference,
        barcode: data['barcode']?.toString() ?? '',
        imageUrl: data['imageUrl']?.toString(),
        availableLocations: List<String>.from(data['availableLocations'] ?? []),
        stockQuantity: _parseDouble(data['stockQuantity']),
        minStockLevel: _parseDouble(data['minStockLevel']),
        trackStock: data['trackStock'] as bool? ?? false,
        isDeleted: data['isDeleted'] as bool? ?? false,
        createdAt: data['createdAt'] as Timestamp?,
        updatedAt: data['updatedAt'] as Timestamp?,
      );
    } catch (e) {
      throw FormatException('Failed to parse product: $e');
    }
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'categoryRef': categoryRef,
      'barcode': barcode,
      'imageUrl': imageUrl,
      'availableLocations': availableLocations,
      'stockQuantity': stockQuantity,
      'minStockLevel': minStockLevel,
      'trackStock': trackStock,
      'isDeleted': isDeleted,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  Product copyWith({
    String? name,
    double? price,
    DocumentReference? categoryRef,
    String? barcode,
    String? imageUrl,
    List<String>? availableLocations,
    double? stockQuantity,
    double? minStockLevel,
    bool? trackStock,
    bool? isDeleted,
    Timestamp? updatedAt,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      categoryRef: categoryRef ?? this.categoryRef,
      barcode: barcode ?? this.barcode,
      imageUrl: imageUrl ?? this.imageUrl,
      availableLocations: availableLocations ?? this.availableLocations,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      trackStock: trackStock ?? this.trackStock,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String? validateBarcode(String? value) {
    if (value == null || value.isEmpty) return 'Barcode is required';
    if (value.length < 3) return 'Barcode too short (min 3 chars)';
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
      return 'Only alphanumeric characters allowed';
    }
    return null;
  }

  factory Product.fromMap(Map<String, dynamic> data, String id) {
    return Product(
      id: id,
      name: data['name']?.toString() ?? '',
      price: _parseDouble(data['price']),
      categoryRef: data['categoryRef'] as DocumentReference,
      barcode: data['barcode']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString(),
      availableLocations: List<String>.from(data['availableLocations'] ?? []),
      stockQuantity: _parseDouble(data['stockQuantity']),
      minStockLevel: _parseDouble(data['minStockLevel']),
      trackStock: data['trackStock'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }


}