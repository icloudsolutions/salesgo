import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/sale.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  // Ventes
  Future<void> recordSale(Sale sale) async {
    await _firestore.collection('sales').add(sale.toMap());
  }

  // Stocks
  Stream<Map<String, int>> getCarStock(String carId) {
    return _firestore.collection('cars/$carId/stock')
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
      print('Error fetching sales: $e');
      return []; // Return empty list on error
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
  Future<void> addDiscount(Map<String, dynamic> discountData) async {
    await _firestore.collection('discounts').add(discountData);
  }

  Stream<QuerySnapshot> getDiscounts() {
    return _firestore.collection('discounts').snapshots();
  }

  Future<void> deleteDiscount(String discountId) async {
    await _firestore.collection('discounts').doc(discountId).delete();
  }
}


