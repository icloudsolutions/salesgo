import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class StockViewModel with ChangeNotifier {
  final FirestoreService _firestoreService;
  Map<String, int> _stock = {};
  bool _isLoading = false;

  StockViewModel({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  Map<String, int> get stock => _stock;
  bool get isLoading => _isLoading;

  void loadStock(String carId) {
    _isLoading = true;
    notifyListeners();
    
    _firestoreService.getCarStock(carId).listen((stockData) {
      _stock = stockData;
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading stock: $error');
    });
  }
}