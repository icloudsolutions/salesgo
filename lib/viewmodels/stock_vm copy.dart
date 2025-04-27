import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class StockViewModel with ChangeNotifier {
  final FirestoreService _firestoreService;
  Map<String, int> _stock = {};
  Map<String, int> _monthlySales = {};
  bool _isLoading = false;
  StreamSubscription<Map<String, int>>? _stockSubscription;
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

  void loadStock(String locationId) {
    _stockSubscription?.cancel();
    _salesSubscription?.cancel();
    
    _isLoading = true;
    notifyListeners();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load current stock
      _stockSubscription = _firestoreService.getLocationStock(locationId).listen(
        (stockData) {
          _stock = stockData;
          _loadMonthlySales(locationId);
        },
        onError: (error) {
          _isLoading = false;
          notifyListeners();
          debugPrint('Error loading stock: $error');
        },
      );
    });
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
    _stockSubscription?.cancel();
    _salesSubscription?.cancel();
    super.dispose();
  }
}