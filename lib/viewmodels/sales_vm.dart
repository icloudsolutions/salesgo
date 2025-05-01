import 'package:flutter/material.dart';
import 'package:salesgo/models/discount.dart';
import 'package:salesgo/models/product.dart';
import 'package:salesgo/models/sale.dart';
import 'package:salesgo/models/cart_item.dart';
import 'package:salesgo/services/firestore_service.dart';
import 'package:uuid/uuid.dart';

class SalesViewModel with ChangeNotifier {
  final List<CartItem> _cartItems = [];
  final FirestoreService _firestoreService;
  final Uuid _uuid = const Uuid();

  SalesViewModel({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  // 🔒 Accès externe en lecture seule
  List<CartItem> get cartItems => List.unmodifiable(_cartItems);

  // 💲 Total des prix avec remises appliquées
  double get totalAmount => _calculateTotal();

  // ➕ Ajouter une ligne produit unique au panier
  void addToCart(Product product) {
    final cartItem = CartItem(
      id: _uuid.v4(),
      product: product,
    );
    _cartItems.add(cartItem);
    notifyListeners();
  }

  // ➖ Supprimer une ligne du panier
  void removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  // 🎯 Appliquer une remise à une ligne spécifique
  void selectDiscountForCartItem(String cartItemId, Discount? discount) {
    try {
      final cartItem = _cartItems.firstWhere((item) => item.id == cartItemId);
      cartItem.discount = discount;
      notifyListeners();
    } catch (_) {
      // CartItem introuvable : rien à faire
    }
  }

  // 📌 Obtenir la remise d'une ligne spécifique
  Discount? getSelectedDiscountForCartItem(String cartItemId) {
    try {
      return _cartItems.firstWhere((item) => item.id == cartItemId).discount;
    } catch (_) {
      return null;
    }
  }

  // 💾 Confirmer la vente et enregistrer dans Firestore
  Future<void> confirmSale({
    required String paymentMethod,
    required String agentId,
    required String locationId,
    String? couponCode,
  }) async {
    if (_cartItems.isEmpty) {
      throw Exception('Cannot confirm sale with an empty cart.');
    }

    try {
      final discountedProducts = _cartItems.map((item) {
        final discount = item.discount;
        final finalPrice = discount != null
            ? _calculatePriceWithDiscount(item.product.price, discount)
            : item.product.price;

        return Product(
          id: item.product.id,
          name: item.product.name,
          price: finalPrice,
          categoryRef: item.product.categoryRef,
          barcode: item.product.barcode,
          imageUrl: item.product.imageUrl,
        );
      }).toList();

      final total = discountedProducts.fold(
        0.0,
        (sum, product) => sum + (product.price ?? 0),
      );

      final sale = Sale(
        id: _uuid.v4(),
        agentId: agentId,
        locationId: locationId,
        date: DateTime.now(),
        products: discountedProducts,
        totalAmount: total,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
      );

      await _firestoreService.recordSale(sale);
      clearCart();
    } catch (e) {
      debugPrint('Error confirming sale: $e');
      rethrow;
    }
  }

  // 🧹 Vider le panier
  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  // 🧮 Calcul du total avec remises
  double _calculateTotal() {
    return _cartItems.fold(0.0, (sum, item) {
      final discount = item.discount;
      final basePrice = item.product.price;
      final price = discount != null
          ? _calculatePriceWithDiscount(basePrice, discount)
          : basePrice;
      return sum + (price ?? 0);
    });
  }

  // 📉 Appliquer une remise à un prix
  double _calculatePriceWithDiscount(double basePrice, Discount discount) {
    return discount.type == '%'
        ? basePrice * (1 - discount.value / 100)
        : basePrice - discount.value;
  }
}
