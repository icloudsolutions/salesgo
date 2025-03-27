import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:salesgo/models/product.dart';

class Sale {
  final String id;
  final String agentId;
  final DateTime date;
  final List<Product> products;
  final double totalAmount;
  final String paymentMethod;
  final String? couponCode;

  Sale({
    required this.id,
    required this.agentId,
    required this.date,
    required this.products,
    required this.totalAmount,
    required this.paymentMethod,
    this.couponCode,
  });

  // Convert Sale object to Map for Firestore
  Map<String, dynamic> toMap() => {
    'id': id,
    'agentId': agentId,
    'date': date,
    'products': products.map((p) => p.toMap()).toList(),
    'totalAmount': totalAmount,
    'paymentMethod': paymentMethod,
    'couponCode': couponCode,
  };

  // Create Sale object from Firestore document
  factory Sale.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Sale(
      id: doc.id,
      agentId: data['agentId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      products: (data['products'] as List?)?.map((p) => 
        Product.fromMap(p as Map<String, dynamic>)).toList() ?? [],
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] as String? ?? '',
      couponCode: data['couponCode'] as String?,
    );
  }

  static List<Product> _parseProducts(dynamic productsData) {
    if (productsData is! List) return [];
    return productsData.map((p) => Product.fromMap(p as Map<String, dynamic>)).toList();
  }

}