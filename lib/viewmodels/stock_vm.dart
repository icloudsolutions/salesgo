import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class StockViewModel with ChangeNotifier {
  final FirestoreService _firestoreService;
  Map<String, int> _stock = {};

  StockViewModel({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  Map<String, int> get stock => _stock;

  void loadStock(String carId) {
    _firestoreService.getCarStock(carId).listen((stockData) {
      _stock = stockData;
      notifyListeners();
    });
  }
}