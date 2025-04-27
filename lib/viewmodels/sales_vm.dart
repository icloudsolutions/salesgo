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

  // Select a discount for a specific product
  void selectDiscountForProduct(String productId, Discount? discount) {
    _selectedDiscounts[productId] = discount;
    notifyListeners();
  }

  // Get selected discount for a product
  Discount? getSelectedDiscountForProduct(String productId) {
    return _selectedDiscounts[productId];
  }

  // Add product to cart
  void addToCart(Product product) {
    _cartItems.add(product);
    notifyListeners();
  }

  // Remove product from cart
  void removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  // Confirm and save the sale
  Future<void> confirmSale({
    required String paymentMethod,
    required String agentId,
    required String locationId, // 🔥 locationId now required
    String? couponCode,
  }) async {
    try {
      if (_cartItems.isEmpty) {
        throw Exception('Cannot confirm sale with an empty cart.');
      }

      // Apply discounts if any
      final discountedProducts = _cartItems.map((product) {
        final discount = _selectedDiscounts[product.id];
        if (discount != null) {
          return Product(
            id: product.id,
            name: product.name,
            price: _calculatePriceWithDiscount(product.price, discount),
            categoryRef: product.categoryRef,
            barcode: product.barcode,
            imageUrl: product.imageUrl,
          );
        }
        return product;
      }).toList();

      final sale = Sale(
        id: _uuid.v4(),
        agentId: agentId,
        locationId: locationId, // 🔥 set correctly here
        date: DateTime.now(),
        products: discountedProducts,
        totalAmount: discountedProducts.fold(0, (sum, item) => sum + item.price),
        paymentMethod: paymentMethod,
        couponCode: couponCode,
      );

      await _firestoreService.recordSale(sale);
      clearCart();
      _selectedDiscounts.clear(); // Clear applied discounts after sale
    } catch (e) {
      debugPrint('Error confirming sale: $e');
      rethrow;
    }
  }

  // Clear the cart
  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  // Calculate the total price
  double _calculateTotal() {
    return _cartItems.fold(0, (sum, item) => sum + (item.price ?? 0));
  }

  // Calculate price after applying discount
  double _calculatePriceWithDiscount(double basePrice, Discount discount) {
    return discount.type == '%' 
        ? basePrice * (1 - discount.value / 100)
        : basePrice - discount.value;
  }
}
