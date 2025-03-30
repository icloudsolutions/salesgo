import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/stock_vm.dart';
import '../../models/product.dart';
import '../../viewmodels/auth_vm.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  int _selectedTabIndex = 0; // 0 for current stock, 1 for history

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stock Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Current Stock'),
              Tab(text: 'Stock History'),
            ],
          ),
        ),
        body: Consumer2<AuthViewModel, StockViewModel>(
          builder: (context, authVM, stockVM, _) {
            return _buildBody(authVM, stockVM);
          },
        ),
      ),
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

    return TabBarView(
      children: [
        // Current Stock Tab
        _buildCurrentStockTab(stockVM),
        
        // Stock History Tab
        _buildStockHistoryTab(authVM),
      ],
    );
  }

  Widget _buildCurrentStockTab(StockViewModel stockVM) {
    if (stockVM.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(
                  title: Text('Loading...'),
                  leading: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return ListTile(
                  title: Text('Product ID: $productId'),
                  subtitle: Text(snapshot.hasError 
                    ? 'Error loading product' 
                    : 'Product not found'),
                );
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

  Widget _buildStockHistoryTab(AuthViewModel authVM) {
    final carId = authVM.currentUser?.assignedCarId;
    if (carId == null) {
      return const Center(child: Text('No car assigned'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stockHistory')
          .where('carId', isEqualTo: carId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('Stock history error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Error loading stock history'),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No stock history available for your vehicle'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                title: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('products')
                      .doc(data['productId'])
                      .get(),
                  builder: (context, productSnapshot) {
                    if (productSnapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Loading product...');
                    }
                    if (!productSnapshot.hasData || !productSnapshot.data!.exists) {
                      return Text('Product ID: ${data['productId']}');
                    }
                    final product = Product.fromFirestore(productSnapshot.data!);
                    return Text(product.name);
                  },
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quantity: ${data['quantity']}'),
                    if (data.containsKey('adminName'))
                      Text('Updated by: ${data['adminName']}'),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(
                        (data['timestamp'] as Timestamp).toDate(),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                trailing: Text(
                  (data['quantity'] as int) > 0 ? '➕' : '➖',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            );
          },
        );
      },
    );
  }
}