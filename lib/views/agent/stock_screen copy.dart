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
  int _selectedTabIndex = 0;

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
    
    if (authVM.currentUser?.assignedLocationId != null) {
      stockVM.loadStock(authVM.currentUser!.assignedLocationId!);
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
    if (authVM.currentUser == null) {
      return const Center(child: Text('Please log in'));
    }

    if (authVM.currentUser!.assignedLocationId == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('No location assigned to you'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Refresh'),
          ),
          const SizedBox(height: 20),
          Text(
            'Please contact your administrator to assign a location',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('locations')
          .doc(authVM.currentUser!.assignedLocationId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final location = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        
        return TabBarView(
          children: [
            _buildCurrentStockTab(stockVM, location),
            _buildStockHistoryTab(authVM, location),
          ],
        );
      },
    );
  }

  Widget _buildCurrentStockTab(StockViewModel stockVM, Map<String, dynamic> location) {
    if (stockVM.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (stockVM.stock.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('No stock available at ${location['name']} (${location['type']})'),
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

  Widget _buildStockHistoryTab(AuthViewModel authVM, Map<String, dynamic> location) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stockHistory')
          .where('locationId', isEqualTo: authVM.currentUser!.assignedLocationId)
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
          return Center(
            child: Text('No stock history at ${location['name']}'),
          );
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
                    Text('Location: ${location['name']} (${location['type']})'),
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