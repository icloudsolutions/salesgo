import 'package:flutter/material.dart';
import 'package:salesgo/models/product.dart';
import 'package:salesgo/models/sale.dart';
import 'package:salesgo/services/firestore_service.dart';
import 'package:uuid/uuid.dart';

class SalesViewModel with ChangeNotifier {
  final List<Product> _cartItems = [];
  final FirestoreService _firestoreService;

  SalesViewModel({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  List<Product> get cartItems => _cartItems;

  double get totalAmount {
    return _cartItems.fold(0, (sum, item) => sum + item.price);
  }

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
    String? couponCode,
  }) async {
    final sale = Sale(
      id: Uuid().v4(),
      agentId: 'current_user_id', // Get from auth
      date: DateTime.now(),
      products: _cartItems,
      totalAmount: _calculateTotal(),
      paymentMethod: paymentMethod,
    );

    await _firestoreService.recordSale(sale);
    _cartItems.clear();
    notifyListeners();
  }

  double _calculateTotal() {
    return _cartItems.fold(0, (sum, item) => sum + item.price);
  }
}