import 'package:flutter/material.dart';
import 'package:salesgo/models/product.dart';
import 'package:salesgo/models/sale.dart';
import 'package:salesgo/services/firestore_service.dart';
import 'package:uuid/uuid.dart';

class SalesViewModel with ChangeNotifier {
  final List<Product> _cartItems = [];
  final FirestoreService _firestoreService;
  final Uuid _uuid = const Uuid();

  SalesViewModel({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  List<Product> get cartItems => List.unmodifiable(_cartItems);

  double get totalAmount => _calculateTotal();

  void addToCart(Product product) {
    _cartItems.add(product);
    notifyListeners();
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> confirmSale({
    required String paymentMethod,
    required String agentId,
    String? couponCode,
  }) async {
    try {
      if (_cartItems.isEmpty) {
        throw Exception('Cannot confirm sale with empty cart');
      }

      final sale = Sale(
        id: _uuid.v4(),
        agentId: agentId,
        date: DateTime.now(),
        products: List.unmodifiable(_cartItems),
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
      );

      await _firestoreService.recordSale(sale);
      clearCart();
    } catch (e) {
      rethrow;
    }
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  double _calculateTotal() {
    return _cartItems.fold(0, (sum, item) => sum + (item.price ?? 0));
  }
}