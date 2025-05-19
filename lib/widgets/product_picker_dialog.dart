import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:salesgo/models/product.dart';

class ProductPickerDialog extends StatefulWidget {
  final void Function(Product product, int quantity) onProductSelected;
  final String? title;

  const ProductPickerDialog({
    super.key,
    required this.onProductSelected,
    this.title,
  });

  @override
  State<ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<ProductPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, int> _selectedQuantities = {};

  Stream<QuerySnapshot<Map<String, dynamic>>> _getProductStream() {
    final ref = FirebaseFirestore.instance.collection('products');
    if (_searchQuery.trim().isEmpty) {
      return ref.limit(30).snapshots();
    }
    return ref
        .where('name', isGreaterThanOrEqualTo: _searchQuery)
        .where('name', isLessThanOrEqualTo: '$_searchQuery\uf8ff')
        .limit(30)
        .snapshots();
  }

  void _onSelect(Product product) {
    final quantity = _selectedQuantities[product.id] ?? 1;
    widget.onProductSelected(product, quantity);
    Navigator.pop(context);
  }

  Widget _quantitySelector(String productId) {
    final quantity = _selectedQuantities[productId] ?? 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: quantity > 1
              ? () => setState(() => _selectedQuantities[productId] = quantity - 1)
              : null,
        ),
        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => setState(() => _selectedQuantities[productId] = quantity + 1),
        ),
      ],
    );
  }

  Widget _buildStockStatus(Product product) {
    if (product.trackStock && product.stockQuantity <= product.minStockLevel) {
      return const Text(
        '⚠️ Low Stock',
        style: TextStyle(color: Colors.redAccent, fontSize: 12),
      );
    }
    return Text('Stock: ${product.stockQuantity.toStringAsFixed(0)}');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title ?? 'Select Product'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _getProductStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No products found.'));
                  }

                  final products = snapshot.data!.docs
                      .map((doc) => Product.fromFirestore(doc))
                      .toList();

                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      _selectedQuantities.putIfAbsent(product.id, () => 1);

                      return ListTile(
                        title: Text(product.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStockStatus(product),
                            Text('Price: \$${product.price.toStringAsFixed(2)}'),
                          ],
                        ),
                        trailing: _quantitySelector(product.id),
                        onTap: () => _onSelect(product),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Cancel"),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
