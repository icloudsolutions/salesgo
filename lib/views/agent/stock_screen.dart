import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/stock_vm.dart';

class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stockVM = Provider.of<StockViewModel>(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Actuel')),
      body: ListView.builder(
        itemCount: stockVM.stock.keys.length,
        itemBuilder: (context, index) {
          final productId = stockVM.stock.keys.elementAt(index);
          return ListTile(
            title: Text('Produit $productId'),
            subtitle: Text('Quantité: ${stockVM.stock[productId]}'),
          );
        },
      ),
    );
  }
}