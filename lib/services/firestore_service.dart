import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:salesgo/models/discount.dart';
import '../models/product.dart';
import '../models/sale.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Product> addProduct({
    required String name,
    required double price,
    required String categoryId,
    required String barcode,
    String? imageUrl,
  }) async {
    final cleanedBarcode = barcode.trim().toUpperCase();
    
    if (!await isBarcodeUnique(cleanedBarcode)) {
      throw 'Product with barcode "$cleanedBarcode" already exists';
    }

    final productRef = _firestore.collection('products').doc();
    final product = Product(
      id: productRef.id,
      name: name,
      price: price,
      categoryRef: _firestore.collection('categories').doc(categoryId),
      barcode: cleanedBarcode,
      imageUrl: imageUrl,

    );

    await productRef.set(product.toMap());
    return product;
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    required double price,
    required String categoryId,
    required String barcode,
    String? imageUrl,
  }) async {
    final cleanedBarcode = barcode.trim().toUpperCase();
    
    if (!await isBarcodeUnique(cleanedBarcode, excludeProductId: productId)) {
      throw 'Product with barcode "$cleanedBarcode" already exists';
    }

    await _firestore.collection('products').doc(productId).update({
      'name': name,
      'price': price,
      'categoryRef': _firestore.collection('categories').doc(categoryId),
      'barcode': cleanedBarcode,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> isBarcodeUnique(String barcode, {String? excludeProductId}) async {
    final query = _firestore.collection('products')
      .where('barcode', isEqualTo: barcode.trim().toUpperCase());

    if (excludeProductId != null) {
      query.where(FieldPath.documentId, isNotEqualTo: excludeProductId);
    }

    final snapshot = await query.limit(1).get();
    return snapshot.docs.isEmpty;
  }



  // Produits
  Future<Product?> getProductByBarcode(String barcode) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('barcode', isEqualTo: barcode)
        .limit(1)
        .get();

    return snapshot.docs.isEmpty 
        ? null 
        : Product.fromFirestore(snapshot.docs.first);
  }

  // For getting products by category
  Future<List<Product>> getProductsByCategory(DocumentReference categoryRef) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('categoryRef', isEqualTo: categoryRef)
        .get();

    return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
  } 



  Future<DocumentReference> getCategoryReference(String categoryId) async {
    return FirebaseFirestore.instance.collection('categories').doc(categoryId);
  }

  // Ventes
  Future<void> recordSale(Sale sale) async {
    await _firestore.collection('sales').add(sale.toMap());
  }

  Stream<Map<String, int>> getMonthlySales(String locationId, DateTime firstDayOfMonth) {
    return FirebaseFirestore.instance
        .collection('sales')
        .where('locationId', isEqualTo: locationId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
        .snapshots()
        .map((snapshot) {
          debugPrint('Fetched sales count: ${snapshot.docs.length}');
          
          for (final doc in snapshot.docs) {
            debugPrint('Fetched sale: ${doc.data()}');
          }

          final monthlySales = <String, int>{};
          for (final doc in snapshot.docs) {
            final sale = doc.data() as Map<String, dynamic>;
            final List<dynamic> products = sale['products'] ?? [];

            for (final product in products) {
              final productId = product['id'] as String;

              //  Check if 'quantity' exists, else default to 1
              final quantity = (product['quantity'] != null) 
                  ? product['quantity'] as int 
                  : 1;

              monthlySales[productId] = (monthlySales[productId] ?? 0) + quantity;
            }
          }
          return monthlySales;
        });
  }




  // Stocks
  Stream<Map<String, int>> getLocationStock(String locationId) {
    return _firestore.collection('locations/$locationId/stock')
      .snapshots()
      .map((snapshot) => {
        for (var doc in snapshot.docs)
          doc.id: doc.data()['quantity'] as int
      });
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getActiveDiscounts(DateTime now) async {
    return await _firestore.collection('discounts')
        .where('startDate', isLessThanOrEqualTo: now)
        .where('endDate', isGreaterThanOrEqualTo: now)
        .get();
  }

  // For getting discounts by category
  Future<List<Discount>> getDiscountsByCategory(DocumentReference categoryRef) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('discounts')
        .where('categoryRef', isEqualTo: categoryRef)
        .get();

    return snapshot.docs.map((doc) => Discount.fromFirestore(doc)).toList();
  } 

  Future<List<Sale>> getAgentSales(String agentId) async {
    final snapshot = await _firestore.collection('sales')
      .where('agentId', isEqualTo: agentId)
      .withConverter<Sale>(
        fromFirestore: (doc, _) => Sale.fromFirestore(doc),
        toFirestore: (sale, _) => sale.toMap(),
      )
      .get();
      
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
  
  Future<List<Sale>> getSalesForAgent(String agentId) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('agentId', isEqualTo: agentId)
          .get();

      return snapshot.docs.map((doc) => Sale.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching sales: $e');
      return []; // Return empty list on error
    }
  }

  Future<void> processRefund({
    required List<Product> products,
    required String agentId,
    required String locationId,
  }) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final refundDoc = FirebaseFirestore.instance.collection('refunds').doc();
      
      // Create refund record
      batch.set(refundDoc, {
        'products': products.map((p) => p.toMap()).toList(),
        'totalAmount': products.fold(0.0, (sum, p) => sum + p.price),
        'agentId': agentId,
        'locationId': locationId,
        'date': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      // Update inventory for each product
      for (final product in products) {
        final productRef = FirebaseFirestore.instance
            .collection('products')
            .doc(product.id);
        
        batch.update(productRef, {
          'stock': FieldValue.increment(1),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to process refund: $e');
    }
  }

  // Categories
  Future<void> addCategory(Map<String, dynamic> categoryData) async {
    await _firestore.collection('categories').add(categoryData);
  }

  Stream<QuerySnapshot> getCategories() {
    return _firestore.collection('categories').snapshots();
  }

  Future<void> deleteCategory(String categoryId) async {
    await _firestore.collection('categories').doc(categoryId).delete();
  }

  // Discounts
  Future<void> addDiscount(Map<String, dynamic> discountData) {
    return _firestore.collection('discounts').add(discountData);
  }

  Future<void> updateDiscount(String id, Map<String, dynamic> discountData) {
    return _firestore.collection('discounts').doc(id).update(discountData);
  }

  Stream<QuerySnapshot> getDiscounts() {
    return _firestore.collection('discounts').snapshots();
  }

  Future<void> deleteDiscount(String id) {
    return _firestore.collection('discounts').doc(id).delete();
  }
}


