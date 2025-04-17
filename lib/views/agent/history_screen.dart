import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:salesgo/models/product.dart';
import 'package:salesgo/models/sale.dart';
import 'package:salesgo/models/discount.dart';
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
            onSelected: (value) => setState(() => _groupBy = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'none', child: Text('No grouping')),
              const PopupMenuItem(value: 'product', child: Text('Group by product')),
              const PopupMenuItem(value: 'category', child: Text('Group by category')),
              const PopupMenuItem(value: 'discount', child: Text('Group by discount')),
              const PopupMenuItem(value: 'payment', child: Text('Group by payment method')),
            ],
          ),
          DropdownButton<String>(
            value: _selectedFilter,
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
      itemBuilder: (context, index) => SaleItem(sale: sales[index]),
    );
  }

  Widget _buildGroupedByProduct(List<Sale> sales) {
    final productGroups = <String, ProductSalesData>{};
    
    for (final sale in sales) {
      for (final product in sale.products) {
        final productId = product.id;
        productGroups.putIfAbsent(productId, () => ProductSalesData(
          product: product,
          sales: [],
        ));
        
        final quantity = sale.products.where((p) => p.id == productId).length;
        productGroups[productId]!.sales.add(sale);
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
                  Text('Category: ${data.product.categoryRef}'),
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
    for (final product in sale.products) {
      final categoryId = product.categoryRef.id;
      
      // Initialize category group if not exists
      if (!categoryGroups.containsKey(categoryId)) {
        categoryGroups[categoryId] = CategorySalesData(
          categoryId: categoryId,
          sales: [],
        );
      }
      
      // Calculate quantity of products in this category for this sale
      final quantityInSale = sale.products
          .where((p) => p.categoryRef.id == categoryId)
          .length;
      
      // Update category group data
      categoryGroups[categoryId]!.sales.add(sale);
      categoryGroups[categoryId]!.totalQuantity += quantityInSale;
      categoryGroups[categoryId]!.totalAmount += product.price * quantityInSale;
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
          // Get category name or fallback
          final categoryName = snapshot.hasData 
              ? snapshot.data!.get('name') ?? 'Uncategorized'
              : 'Loading...';
          
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
                          return const CircularProgressIndicator();
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