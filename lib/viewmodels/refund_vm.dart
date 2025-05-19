import 'package:cloud_firestore/cloud_firestore.dart';
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

  Product? _originalProduct;
  Product? _replacementProduct;
  int _originalQty = 1;
  int _replacementQty = 1;

  Product? get originalProduct => _originalProduct;
  Product? get replacementProduct => _replacementProduct;
  int get originalQty => _originalQty;
  int get replacementQty => _replacementQty;

  void setOriginalProduct(Product product, int qty) {
    _originalProduct = product;
    _originalQty = qty;
    notifyListeners();
  }

  void setReplacementProduct(Product product, int qty) {
    _replacementProduct = product;
    _replacementQty = qty;
    notifyListeners();
  }

  void clearExchange() {
    _originalProduct = null;
    _replacementProduct = null;
    _originalQty = 1;
    _replacementQty = 1;
    notifyListeners();
  }

  double get priceDifference {
    final oldTotal = (_originalProduct?.price ?? 0.0) * _originalQty;
    final newTotal = (_replacementProduct?.price ?? 0.0) * _replacementQty;
    return newTotal - oldTotal;
  }

  Future<void> processExchange({
    required String agentId,
    required String locationId,
    required String reason,
  }) async {
    if (_originalProduct == null || _replacementProduct == null) return;

    final batch = FirebaseFirestore.instance.batch();

    final exchangeRef = FirebaseFirestore.instance.collection('refunds').doc();

    batch.set(exchangeRef, {
      'type': 'exchange',
      'agentId': agentId,
      'locationId': locationId,
      'date': FieldValue.serverTimestamp(),
      'reason': reason,
      'originalProduct': _originalProduct!.toMap()..['quantity'] = _originalQty,
      'replacementProduct': _replacementProduct!.toMap()..['quantity'] = _replacementQty,
      'priceDifference': priceDifference,
    });

    final oldRef = FirebaseFirestore.instance.collection('products').doc(_originalProduct!.id);
    final newRef = FirebaseFirestore.instance.collection('products').doc(_replacementProduct!.id);

    batch.update(oldRef, {'stockQuantity': FieldValue.increment(_originalQty)});
    batch.update(newRef, {'stockQuantity': FieldValue.increment(-_replacementQty)});

    await batch.commit();
    clearExchange();
  }


}