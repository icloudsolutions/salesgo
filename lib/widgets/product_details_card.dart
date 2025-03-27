import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/discount.dart';
import 'discount_badge.dart';
import '../viewmodels/discount_vm.dart';
import 'package:provider/provider.dart';

class ProductDetailsCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onRemove;

  const ProductDetailsCard({
    super.key,
    required this.product,
    this.onRemove,
  });

  double _calculateFinalPrice(double basePrice, List<Discount> discounts) {
    if (discounts.isEmpty) return basePrice;
    
    // Get the highest applicable discount
    final applicableDiscounts = discounts.where((d) => d.category == product.category).toList();
    if (applicableDiscounts.isEmpty) return basePrice;

    final maxDiscount = applicableDiscounts
      .map((d) => d.type == '%' ? basePrice * (d.value / 100) : d.value)
      .reduce((a, b) => a > b ? a : b);

    return basePrice - maxDiscount;
  }

  @override
  Widget build(BuildContext context) {
    final discountVM = Provider.of<DiscountViewModel>(context);

    final finalPrice = _calculateFinalPrice(
      product.price,
      discountVM.activeDiscounts,
    );

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Product Image
                if (product.imageUrl != null)
                  Image.network(
                    product.imageUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                if (product.imageUrl == null || product.imageUrl!.isEmpty)
                  Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                const SizedBox(width: 16),
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.category,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Remove Button (only shown if onRemove callback is provided)
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onRemove,
                  ),
              ],
            ),
            const Divider(),
            // Price Information
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Final Price:',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  '€${finalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (finalPrice < product.price)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Original Price: €${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // Discount Badges
            Wrap(
              spacing: 8,
              children: discountVM.activeDiscounts
                  .where((d) => d.category == product.category)
                  .map((discount) => DiscountBadge(discount: discount))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}