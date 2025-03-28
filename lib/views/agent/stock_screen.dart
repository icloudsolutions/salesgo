import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/stock_vm.dart';
import '../../models/product.dart';
import '../../viewmodels/auth_vm.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final stockVM = Provider.of<StockViewModel>(context, listen: false);
    
    if (authVM.currentUser?.assignedCarId != null) {
        stockVM.loadStock(authVM.currentUser!.assignedCarId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockVM = Provider.of<StockViewModel>(context);
    final authVM = Provider.of<AuthViewModel>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Current Stock')),
      body: _buildBody(authVM, stockVM),
    );
  }

  Widget _buildBody(AuthViewModel authVM, StockViewModel stockVM) {
    // No user logged in
    if (authVM.currentUser == null) {
      return const Center(child: Text('Please log in'));
    }

    // No car assigned
    if (authVM.currentUser!.assignedCarId == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('No car assigned to you'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Refresh'),
          ),
          const SizedBox(height: 20),
          Text(
            'Please contact your administrator to assign a vehicle',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // Loading state
    if (stockVM.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Empty stock
    if (stockVM.stock.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('No stock available for your assigned vehicle'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Refresh'),
          ),
        ],
      );
    }

    // Show stock list
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: stockVM.stock.keys.length,
        itemBuilder: (context, index) {
          final productId = stockVM.stock.keys.elementAt(index);
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('products')
                .doc(productId)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const ListTile(title: Text('Loading product...'));
              }
              final product = Product.fromFirestore(snapshot.data!);
              return ListTile(
                title: Text(product.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quantity: ${stockVM.stock[productId]}'),
                    if (product.barcode.isNotEmpty)
                      Text('Barcode: ${product.barcode}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                trailing: Text('${product.price.toStringAsFixed(2)} €',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}