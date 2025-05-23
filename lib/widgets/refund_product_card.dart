import 'package:flutter/material.dart';
import '../models/product.dart';

class RefundProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onRemove;

  const RefundProductCard({
    super.key,
    required this.product,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: ListTile(
        title: Text(product.name),
        subtitle: Text('Price: €${product.price?.toStringAsFixed(2) ?? 'N/A'}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
