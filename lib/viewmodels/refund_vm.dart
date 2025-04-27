import 'package:flutter/material.dart';
import 'package:salesgo/models/product.dart';
import 'package:salesgo/services/firestore_service.dart';

class RefundViewModel with ChangeNotifier {
  final FirestoreService _firestoreService;
  final List<Product> _refundItems = [];
  
  RefundViewModel({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  List<Product> get refundItems => _refundItems;
  
  double get totalRefundAmount => _refundItems.fold(
    0.0, 
    (sum, product) => sum + product.price
  );

  void addToRefund(Product product) {
    _refundItems.add(product);
    notifyListeners();
  }

  void removeFromRefund(int index) {
    _refundItems.removeAt(index);
    notifyListeners();
  }

  void clearRefund() {
    _refundItems.clear();
    notifyListeners();
  }

  Future<void> processRefund({
    required String agentId,
    required String locationId,
  }) async {
    if (_refundItems.isEmpty) return;

    try {
      await _firestoreService.processRefund(
        products: _refundItems,
        agentId: agentId,
        locationId: locationId,
      );
      clearRefund();
    } catch (e) {
      rethrow;
    }
  }
}