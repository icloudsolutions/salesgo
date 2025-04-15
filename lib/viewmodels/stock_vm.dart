import 'dart:async';

import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class StockViewModel with ChangeNotifier {
  final FirestoreService _firestoreService;
  Map<String, int> _stock = {};
  bool _isLoading = false;
  StreamSubscription<Map<String, int>>? _stockSubscription;

  StockViewModel({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  Map<String, int> get stock => _stock;
  bool get isLoading => _isLoading;

  void loadStock(String locationId) {
    // Cancel any existing subscription
    _stockSubscription?.cancel();
    
    _isLoading = true;
    notifyListeners();
    
    // Use a post-frame callback to ensure we're not in build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stockSubscription = _firestoreService.getLocationStock(locationId).listen(
        (stockData) {
          _stock = stockData;
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          _isLoading = false;
          notifyListeners();
          debugPrint('Error loading stock: $error');
        },
      );
    });
  }

  @override
  void dispose() {
    _stockSubscription?.cancel();
    super.dispose();
  }
}