import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:salesgo/models/product.dart';
import 'package:salesgo/models/sale.dart';
import 'package:salesgo/services/firestore_service.dart';
import '../../viewmodels/auth_vm.dart';
import '../../widgets/sale_item.dart';

class ProductSalesData {
  List<Sale> sales;
  int totalQuantity;
  double totalAmount;
  final Product product;

  ProductSalesData({
    required this.product,
    List<Sale>? sales,
    this.totalQuantity = 0,
    this.totalAmount = 0.0,
  }) : sales = sales ?? [];
}

class CategorySalesData {
  final List<Sale> sales;
  int totalQuantity;
  double totalAmount;
  final String categoryId;
  String? categoryName;

  CategorySalesData({
    required this.categoryId,
    List<Sale>? sales,
    this.totalQuantity = 0,
    this.totalAmount = 0.0,
  }) : sales = sales ?? [];
}

class DiscountSalesData {
  final List<Sale> sales;
  int totalQuantity;
  double totalAmount;
  final String discountName;

  DiscountSalesData({
    required this.discountName,
    List<Sale>? sales,
    this.totalQuantity = 0,
    this.totalAmount = 0.0,
  }) : sales = sales ?? [];
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'day';
  String _groupBy = 'product';
  late DateTimeRange _dateRange;

  @override
  void initState() {
    super.initState();
    _updateDateRange();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'day':
        _dateRange = DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: now,
        );
        break;
      case 'week':
        _dateRange = DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
        break;
      case 'month':
        _dateRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
        break;
      default:
        _dateRange = DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
    }
  }

  Future<void> _processRefund(Sale sale, BuildContext context) async {
    if (sale.refunded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This sale has already been refunded')),
      );
      return;
    }

    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final locationId = authVM.currentUser?.assignedLocationId;

    if (locationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location assigned')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Refund'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to process this refund?'),
            const SizedBox(height: 16),
            Text('Sale ID: ${sale.id.substring(0, 8)}'),
            Text('Date: ${DateFormat('MMM dd, yyyy').format(sale.date)}'),
            Text('Total: \$${sale.totalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text('This will:'),
            const Text('- Mark the sale as refunded'),
            const Text('- Restock the items in inventory'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Refund', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Process refund and update stock
      await firestoreService.processRefund(
        products: sale.products,
        agentId: authVM.currentUser!.uid,
        locationId: locationId,
      );

      // Mark sale as refunded
      await FirebaseFirestore.instance
          .collection('sales')
          .doc(sale.id)
          .update({
            'refunded': true,
            'refundDate': FieldValue.serverTimestamp(),
            'refundBy': authVM.currentUser!.uid,
          });

      // Close loading indicator
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund processed successfully!')),
      );
    } catch (e) {
      // Close loading indicator if still open
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refund failed: ${e.toString()}')),
      );
    }
  }

  Widget _buildRefundButton(Sale sale, BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.replay_circle_filled_rounded, color: Colors.red),
      onPressed: () => _processRefund(sale, context),
      tooltip: 'Process Refund',
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final userId = authVM.currentUser?.uid;

    if (userId == null) {
      return const Center(child: Text('User not authenticated'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_alt),
            tooltip: 'Group by',
            onSelected: (value) => setState(() => _groupBy = value),
            itemBuilder: (context) {
              final options = {
                'none': 'No grouping',
                'product': 'Group by product',
                'category': 'Group by category',
                'discount': 'Group by discount',
                'payment': 'Group by payment method',
              };

              return options.entries.map((entry) {
                return PopupMenuItem<String>(
                  value: entry.key,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.value),
                      if (_groupBy == entry.key)
                        const Icon(Icons.check, color: Colors.blueAccent),
                    ],
                  ),
                );
              }).toList();
            },
          ),

          DropdownButton<String>(
            value: _selectedFilter,
            icon: const Icon(Icons.date_range),
            style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
            dropdownColor: const Color.fromARGB(255, 255, 255, 255),            
            items: const [
              DropdownMenuItem(value: 'day', child: Text('Today')),
              DropdownMenuItem(value: 'week', child: Text('This Week')),
              DropdownMenuItem(value: 'month', child: Text('This Month')),
            ],
            onChanged: (value) => setState(() {
              _selectedFilter = value!;
              _updateDateRange();
            }),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('sales')
            .where('agentId', isEqualTo: userId)
            .where('date', isGreaterThanOrEqualTo: _dateRange.start)
            .where('date', isLessThanOrEqualTo: _dateRange.end)
            .orderBy('date', descending: true)
            .snapshots(),
            
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No sales found'));
          }

          final sales = snapshot.data!.docs.map((doc) {
            try {
              return Sale.fromFirestore(doc);
            } catch (e) {
              debugPrint('Error parsing sale: $e');
              return null;
            }
          }).whereType<Sale>().toList();

          switch (_groupBy) {
            case 'none': return _buildSalesList(sales);
            case 'product': return _buildGroupedByProduct(sales);
            case 'category': return _buildGroupedByCategory(sales);
            case 'discount': return _buildGroupedByDiscount(sales);
            case 'payment': return _buildGroupedByPayment(sales);
            default: return _buildSalesList(sales);
          }
        },
      ),
    );
  }

  Widget _buildSalesList(List<Sale> sales) {
    return ListView.builder(
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return ListTile(
          title: Text('Sale #${sale.id}'),
          subtitle: Text(
            'Total: €${sale.totalAmount.toStringAsFixed(2)}\n'
            'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(sale.date)}',
          ),
          trailing: !sale.refunded
              ? IconButton(
                  icon: const Icon(Icons.replay, color: Colors.red),
                  onPressed: () => _processRefund(sale, context),
                )
              : const Text('Refunded', style: TextStyle(color: Colors.grey)),
        );
      },
    );
  }

  void _showRefundConfirmation(BuildContext context, Sale sale) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer le remboursement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vente #${sale.id.substring(0, 6)}'),
            const SizedBox(height: 8),
            Text(
              'Montant: ${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(sale.totalAmount)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Text('Cette action va:'),
            const SizedBox(height: 4),
            const Text('• Marquer la vente comme remboursée'),
            const Text('• Réajuster le stock des articles'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processRefund(sale, context);
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
  Widget _buildGroupedByProduct(List<Sale> sales) {
    final productGroups = <String, ProductSalesData>{};
    
    for (final sale in sales) {
      final productsInSale = <String, int>{}; // <productId, quantity>

      for (final product in sale.products) {
        productsInSale.update(product.id, (value) => value + 1, ifAbsent: () => 1);
      }

      for (final entry in productsInSale.entries) {
        final productId = entry.key;
        final quantity = entry.value;
        final product = sale.products.firstWhere((p) => p.id == productId);

        productGroups.putIfAbsent(productId, () => ProductSalesData(
          product: product,
          sales: [],
        ));

        // Ajoute une seule fois la vente
        productGroups[productId]!.sales.add(sale);

        // Calcule correctement la quantité
        productGroups[productId]!.totalQuantity += quantity;
        productGroups[productId]!.totalAmount += product.price * quantity;
      }
    }


    return ListView(
      children: productGroups.entries.map((entry) {
        final data = entry.value;
        return ExpansionTile(
          leading: data.product.imageUrl != null 
              ? Image.network(data.product.imageUrl!, width: 40, height: 40)
              : const Icon(Icons.shopping_bag),
          title: Text(data.product.name),
          subtitle: Text('${data.totalQuantity} items - Total: €${data.totalAmount.toStringAsFixed(2)}'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<DocumentSnapshot>(
                    future: data.product.categoryRef.get(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final category = snapshot.data!.get('name') ?? 'Uncategorized';
                        return Text('Category: $category');
                      }
                      return const Text('Category: Loading...');
                    },
                  ),
                  //Text('Category: ${data.product.categoryRef}'),
                  Text('Unit price: €${data.product.price.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  const Text('Recent sales:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...data.sales.take(3).map((sale) {
                    final quantityInSale = sale.products.where((p) => p.id == data.product.id).length;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Sale #${sale.id.substring(0, 6)}'),
                      subtitle: Text(DateFormat('MMM dd, HH:mm').format(sale.date)),
                      trailing: Text('$quantityInSale × €${data.product.price.toStringAsFixed(2)}'),
                    );
                  }).toList(),
                  if (data.sales.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('+ ${data.sales.length - 3} more transactions',
                          style: TextStyle(color: Colors.grey[600])),
                    ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildGroupedByCategory(List<Sale> sales) {
    final categoryGroups = <String, CategorySalesData>{};
    
    // Group sales by category
    for (final sale in sales) {
      final categoryQuantities = <String, int>{};
      final categoryAmounts = <String, double>{};
      final productsByCategory = <String, Product>{};

      for (final product in sale.products) {
        final categoryId = product.categoryRef.id;

        categoryQuantities.update(categoryId, (value) => value + 1, ifAbsent: () => 1);
        categoryAmounts.update(categoryId, (value) => value + product.price, ifAbsent: () => product.price);
        
        // Sauvegarder un produit par catégorie pour le prix (on peut en prendre un arbitraire)
        productsByCategory[categoryId] = product;
      }

      for (final categoryId in categoryQuantities.keys) {
        categoryGroups.putIfAbsent(categoryId, () => CategorySalesData(
          categoryId: categoryId,
          sales: [],
        ));

        categoryGroups[categoryId]!.sales.add(sale);
        categoryGroups[categoryId]!.totalQuantity += categoryQuantities[categoryId]!;
        categoryGroups[categoryId]!.totalAmount += categoryAmounts[categoryId]!;
      }
    }


    return ListView(
      children: categoryGroups.entries.map((entry) {
        final data = entry.value;
        
        return FutureBuilder<DocumentSnapshot>(
          future: data.categoryId.contains('/')
              ? FirebaseFirestore.instance.doc(data.categoryId).get()
              : FirebaseFirestore.instance.collection('categories').doc(data.categoryId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const ListTile(
                leading: Icon(Icons.category),
                title: Text('Loading...'),
              );
            }

            String categoryName = 'Uncategorized';
            if (snapshot.hasData && snapshot.data!.exists) {
              categoryName = snapshot.data!.get('name') ?? 'Uncategorized';
            }

            return ExpansionTile(
              leading: const Icon(Icons.category),
              title: Text(categoryName),
              subtitle: Text(
                '${data.totalQuantity} items - Total: €${data.totalAmount.toStringAsFixed(2)}',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top products:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Product>>(
                        future: _getTopProductsInCategory(sales, data.categoryId),
                        builder: (context, productSnapshot) {
                          if (!productSnapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return Column(
                            children: productSnapshot.data!.take(3).map((product) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: product.imageUrl != null
                                    ? Image.network(
                                        product.imageUrl!,
                                        width: 40,
                                        height: 40,
                                      )
                                    : const Icon(Icons.shopping_bag),
                                title: Text(product.name),
                                subtitle: Text('€${product.price.toStringAsFixed(2)}'),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Recent sales:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...data.sales.take(3).map((sale) {
                        final quantityInCategory = sale.products
                            .where((p) => p.categoryRef.id == data.categoryId)
                            .length;
                        final amountInCategory = sale.products
                            .where((p) => p.categoryRef.id == data.categoryId)
                            .fold(0.0, (sum, p) => sum + p.price);
                        
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Sale #${sale.id.substring(0, 6)}'),
                          subtitle: Text(
                            DateFormat('MMM dd, HH:mm').format(sale.date),
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$quantityInCategory items'),
                              Text('€${amountInCategory.toStringAsFixed(2)}'),
                            ],
                          ),
                        );
                      }).toList(),
                      if (data.sales.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '+ ${data.sales.length - 3} more transactions',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      }).toList(),
    );

  }

  Future<List<Product>> _getTopProductsInCategory(List<Sale> sales, String categoryId) async {
    final productCounts = <Product, int>{};
    
    for (final sale in sales) {
      for (final product in sale.products.where((p) => p.categoryRef.id == categoryId)) {
        productCounts[product] = (productCounts[product] ?? 0) + 1;
      }
    }
    
    // Sort products by count in descending order
    final sortedProducts = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedProducts.map((entry) => entry.key).toList();
  }

  Widget _buildGroupedByDiscount(List<Sale> sales) {
    final discountGroups = <String, DiscountSalesData>{};
    
    for (final sale in sales) {
      final discountName = sale.couponCode ?? 'No discount';
      if (!discountGroups.containsKey(discountName)) {
        discountGroups[discountName] = DiscountSalesData(discountName: discountName);
      }
      
      discountGroups[discountName]!.sales.add(sale);
      discountGroups[discountName]!.totalQuantity += sale.products.length;
      discountGroups[discountName]!.totalAmount += sale.totalAmount;
    }

    return ListView(
      children: discountGroups.entries.map((entry) {
        final data = entry.value;
        
        return ExpansionTile(
          leading: const Icon(Icons.discount),
          title: Text(data.discountName),
          subtitle: Text('${data.totalQuantity} items - Total: €${data.totalAmount.toStringAsFixed(2)}'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent sales:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...data.sales.take(3).map((sale) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Sale #${sale.id.substring(0, 6)}'),
                      subtitle: Text(DateFormat('MMM dd, HH:mm').format(sale.date)),
                      trailing: Text('€${sale.totalAmount.toStringAsFixed(2)}'),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildGroupedByPayment(List<Sale> sales) {
    final paymentGroups = <String, List<Sale>>{};
    for (final sale in sales) {
      paymentGroups.putIfAbsent(sale.paymentMethod, () => []).add(sale);
    }

    return ListView(
      children: paymentGroups.entries.map((entry) {
        final paymentMethod = entry.key;
        final paymentSales = entry.value;
        final totalAmount = paymentSales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);

        return ExpansionTile(
          title: Text(paymentMethod.toUpperCase()),
          subtitle: Text('${paymentSales.length} sales - Total: €${totalAmount.toStringAsFixed(2)}'),
          children: paymentSales.map((sale) {
            return ListTile(
              title: Text('Sale #${sale.id.substring(0, 8)}'),
              subtitle: Text(DateFormat('dd/MM/yy HH:mm').format(sale.date)),
              trailing: Text('€${sale.totalAmount.toStringAsFixed(2)}'),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

}