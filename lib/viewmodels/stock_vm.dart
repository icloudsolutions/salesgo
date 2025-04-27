import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class StockViewModel with ChangeNotifier {
  final FirestoreService _firestoreService;
  Map<String, int> _stock = {};
  Map<String, int> _monthlySales = {};
  bool _isLoading = false;
  StreamSubscription<Map<String, int>>? _salesSubscription;

  StockViewModel({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  Map<String, int> get stock => _stock;
  Map<String, int> get monthlySales => _monthlySales;
  bool get isLoading => _isLoading;

  Map<String, int> get adjustedStock {
    final adjusted = <String, int>{};
    _stock.forEach((productId, quantity) {
      adjusted[productId] = quantity - (_monthlySales[productId] ?? 0);
    });
    return adjusted;
  }

  Future<void> loadStock(String locationId) async {
    _salesSubscription?.cancel();

    _isLoading = true;
    notifyListeners();

    try {
      // 🔥 Load assigned stock from stockHistory
      final assignedStock = await _loadAssignedStockFromHistory(locationId);
      _stock = assignedStock;

      _loadMonthlySales(locationId);
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading stock: $error');
    }
  }

  Future<Map<String, int>> _loadAssignedStockFromHistory(String locationId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('stockHistory')
        .where('locationId', isEqualTo: locationId)
        .get();

    final Map<String, int> assignedStock = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final productId = data['productId'] as String;
      final quantity = data['quantity'] as int;

      assignedStock[productId] = (assignedStock[productId] ?? 0) + quantity;
    }
    return assignedStock;
  }

  void _loadMonthlySales(String locationId) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    _salesSubscription = _firestoreService
        .getMonthlySales(locationId, firstDayOfMonth)
        .listen((salesData) {
      _monthlySales = salesData;
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading monthly sales: $error');
    });
  }

  @override
  void dispose() {
    _salesSubscription?.cancel();
    super.dispose();
  }
}
