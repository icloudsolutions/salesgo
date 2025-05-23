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

class _StockScreenState extends State<StockScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final stockVM = Provider.of<StockViewModel>(context, listen: false);
    
    if (authVM.currentUser?.assignedLocationId != null) {
      String locationId = authVM.currentUser!.assignedLocationId!;
      stockVM.loadStock(locationId);
      stockVM.loadRefundedProducts(locationId); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inventory)), 
            Tab(icon: Icon(Icons.history)),
        ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Consumer2<AuthViewModel, StockViewModel>(
        builder: (context, authVM, stockVM, _) {
          if (authVM.currentUser == null) {
            return const Center(child: Text('Please log in'));
          }

          if (authVM.currentUser!.assignedLocationId == null) {
            return _buildNoLocationAssigned(authVM);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCurrentStockTab(stockVM, authVM),
              _buildStockHistoryTab(authVM),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoLocationAssigned(AuthViewModel authVM) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No location assigned'),
          const SizedBox(height: 8),
          Text(
            'Contact your administrator to assign a location',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed:_loadData,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStockTab(StockViewModel stockVM, AuthViewModel authVM) {
    if (stockVM.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final adjustedStock = stockVM.adjustedStock;

    if (adjustedStock.isEmpty) {
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No stock available at ${location['name']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text('Scan products to add stock'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => stockVM.loadStock(authVM.currentUser!.assignedLocationId!),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () async => stockVM.loadStock(authVM.currentUser!.assignedLocationId!),
      child: ListView.builder(
        itemCount: adjustedStock.keys.length,
        itemBuilder: (context, index) {
          final productId = adjustedStock.keys.elementAt(index);
          final quantity = adjustedStock[productId] ?? 0;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('products')
                .doc(productId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(
                  leading: CircularProgressIndicator(),
                  title: Text('Loading product...'),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return ListTile(
                  leading: const Icon(Icons.error),
                  title: Text('Product ID: $productId'),
                  subtitle: const Text('Not found in database'),
                );
              }

              final product = Product.fromFirestore(snapshot.data!);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: product.imageUrl != null
                      ? Image.network(product.imageUrl!, width: 50, height: 50)
                      : const Icon(Icons.shopping_bag),
                  title: Text(product.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available: $quantity'),
                      Text('Initial stock: ${stockVM.stock[productId] ?? 0}'),
                      Text('Sold this month: ${stockVM.monthlySales[productId] ?? 0}'),
                      if (stockVM.refundedProducts[productId] != null) 
                        Text('Refunded: ${stockVM.refundedProducts[productId]}'),// ← New Line
                      if (product.barcode.isNotEmpty)                      
                        Text('Barcode: ${product.barcode}'),
                    ],
                  ),
                  trailing: Text(
                    '€${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Error loading stock history'),
                Text(
                  snapshot.error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('locations')
                .doc(authVM.currentUser!.assignedLocationId)
                .get(),
            builder: (context, locationSnapshot) {
              if (!locationSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final location = locationSnapshot.data!.data() as Map<String, dynamic>? ?? {};
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No stock history at ${location['name']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('Stock changes will appear here'),
                  ],
                ),
              );
            },
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp).toDate();

            // Extract operation type and quantity
            final int quantity = data['quantity'] as int? ?? 0;
            final String type = data['type'] as String? ?? 'unknown';
            final String productId = data['productId'] as String? ?? '';

            // Define operation labels and icons
            final Map<String, IconData> typeIcons = {
              'assign': Icons.add_box,
              'refund': Icons.assignment_return,
              'sale': Icons.shopping_cart,
              'manual': Icons.edit,
            };

            final Map<String, Color> typeColors = {
              'assign': Colors.green,
              'refund': Colors.red,
              'sale': Colors.orange,
              'manual': Colors.blue,
            };

            final String displayType = {
              'assign': 'Assigned',
              'refund': 'Refunded',
              'sale': 'Sold',
              'manual': 'Manually Adjusted'
            }[type] ??
                type;

            final String qtyDisplay = (quantity > 0 ? '+' : '') + '$quantity';

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('products')
                  .doc(productId)
                  .get(),
              builder: (context, productSnapshot) {
                if (productSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    leading: CircularProgressIndicator(),
                    title: Text('Loading product...'),
                  );
                }

                Product? product;
                if (productSnapshot.hasData && productSnapshot.data!.exists) {
                  product = Product.fromFirestore(productSnapshot.data!);
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: typeColors[type] ?? Colors.grey,
                      child: Icon(
                        typeIcons[type] ?? Icons.info_outline,
                        color: Colors.white,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(displayType),
                        Text(
                          qtyDisplay,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: quantity > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product != null) Text('Product: ${product.name}'),
                        Text(
                          DateFormat('MMM dd, yyyy - HH:mm').format(timestamp),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}