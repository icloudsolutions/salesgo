import 'package:flutter/material.dart';
import 'package:salesgo/models/discount.dart';
import 'package:salesgo/models/product.dart';
import 'package:salesgo/models/sale.dart';
import 'package:salesgo/services/firestore_service.dart';
import 'package:uuid/uuid.dart';

class SalesViewModel with ChangeNotifier {
  final List<Product> _cartItems = [];
  final FirestoreService _firestoreService;
  final Uuid _uuid = const Uuid();
  final Map<String, Discount?> _selectedDiscounts = {};

  SalesViewModel({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  List<Product> get cartItems => List.unmodifiable(_cartItems);

  double get totalAmount => _calculateTotal();

  // Method to set selected discount for a product
  void selectDiscountForProduct(String productId, Discount? discount) {
    _selectedDiscounts[productId] = discount;
    notifyListeners();
  }

  // Method to get selected discount for a product
  Discount? getSelectedDiscountForProduct(String productId) {
    return _selectedDiscounts[productId];
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
  required String agentId,
  String? couponCode,
}) async {
  try {
    if (_cartItems.isEmpty) {
      throw Exception('Cannot confirm sale with empty cart');
    }

    // Apply selected discounts to products
    final discountedProducts = _cartItems.map((product) {
      final discount = _selectedDiscounts[product.id];
      if (discount != null) {
        return Product(
          id: product.id,
          name: product.name,
          price: _calculatePriceWithDiscount(product.price, discount),
          category: product.category,
          barcode: product.barcode,
          imageUrl: product.imageUrl,
        );
      }
      return product;
    }).toList();

    final sale = Sale(
      id: _uuid.v4(),
      agentId: agentId,
      date: DateTime.now(),
      products: discountedProducts,
      totalAmount: discountedProducts.fold(0, (sum, item) => sum + item.price),
      paymentMethod: paymentMethod,
      couponCode: couponCode,
    );

    await _firestoreService.recordSale(sale);
    clearCart();
    _selectedDiscounts.clear(); // Clear selected discounts after sale
  } catch (e) {
    rethrow;
  }
}

double _calculatePriceWithDiscount(double basePrice, Discount discount) {
  return discount.type == '%' 
      ? basePrice * (1 - discount.value / 100)
      : basePrice - discount.value;
}

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  double _calculateTotal() {
    return _cartItems.fold(0, (sum, item) => sum + (item.price ?? 0));
  }
}