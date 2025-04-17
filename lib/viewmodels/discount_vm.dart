import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/discount.dart';

class DiscountViewModel with ChangeNotifier {
  final FirestoreService _firestoreService;
  List<Discount> _activeDiscounts = [];
  bool _isLoading = false;
  String? _error;

  DiscountViewModel({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  List<Discount> get activeDiscounts => List.unmodifiable(_activeDiscounts);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadActiveDiscounts() async {
    _setLoading(true);
    _error = null;
    
    try {
      final now = DateTime.now();
      final snapshot = await _firestoreService.getActiveDiscounts(now);
      
      _activeDiscounts = snapshot.docs.map((doc) {
        try {
          return Discount.fromFirestore(doc);
        } catch (e) {
          debugPrint('Error parsing discount document ${doc.id}: $e');
          return null;
        }
      }).whereType<Discount>().toList();
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load discounts: ${e.toString()}';
      debugPrint(_error!);
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Discount>> getDiscountsForCategory(DocumentReference categoryRef) async {
    _setLoading(true);
    try {
      final discounts = await _firestoreService.getDiscountsByCategory(categoryRef);
      return discounts.docs.map((doc) => Discount.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error loading discounts for category: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addDiscount(Discount discount) async {
    _setLoading(true);
    try {
      await _firestoreService.addDiscount(discount.toMap());
      await loadActiveDiscounts(); // Refresh the list
    } catch (e) {
      _error = 'Failed to add discount: ${e.toString()}';
      debugPrint(_error!);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateDiscount(Discount discount) async {
    _setLoading(true);
    try {
      await _firestoreService.updateDiscount(discount.id, discount.toMap());
      await loadActiveDiscounts(); // Refresh the list
    } catch (e) {
      _error = 'Failed to update discount: ${e.toString()}';
      debugPrint(_error!);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteDiscount(String discountId) async {
    _setLoading(true);
    try {
      await _firestoreService.deleteDiscount(discountId);
      _activeDiscounts.removeWhere((d) => d.id == discountId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete discount: ${e.toString()}';
      debugPrint(_error!);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

extension on List<Discount> {
  get docs => null;
}