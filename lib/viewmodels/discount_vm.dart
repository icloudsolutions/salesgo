import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/discount.dart';

class DiscountViewModel with ChangeNotifier {
  final FirestoreService _firestoreService;
  List<Discount> _activeDiscounts = [];

  DiscountViewModel({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  List<Discount> get activeDiscounts => _activeDiscounts;

  Future<void> loadActiveDiscounts() async {
    final now = DateTime.now();
    final snapshot = await _firestoreService.getActiveDiscounts(now);
    _activeDiscounts = snapshot.docs
      .map((doc) => Discount.fromFirestore(doc.data()))
      .toList();
    notifyListeners();
  }
}