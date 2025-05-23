import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/cart_item.dart';
import '../models/discount.dart';
import '../viewmodels/discount_vm.dart';
import '../viewmodels/sales_vm.dart';
import 'discount_badge.dart';

class ProductDetailsCard extends StatefulWidget {
  final CartItem cartItem;
  final VoidCallback? onRemove;

  const ProductDetailsCard({
    super.key,
    required this.cartItem,
    this.onRemove,
  });

  @override
  State<ProductDetailsCard> createState() => _ProductDetailsCardState();
}

class _ProductDetailsCardState extends State<ProductDetailsCard> {
  Discount? _selectedDiscount;

  @override
  void initState() {
    super.initState();
    _selectedDiscount = widget.cartItem.discount;
  }

  @override
  Widget build(BuildContext context) {
    final discountVM = Provider.of<DiscountViewModel>(context);
    final salesVM = Provider.of<SalesViewModel>(context);

    final product = widget.cartItem.product;

    final applicableDiscounts = discountVM.activeDiscounts
        .where((d) => d.categoryRef.path == product.categoryRef.path)
        .toList();

    final finalPrice = _selectedDiscount != null
        ? _calculatePriceWithDiscount(product.price, _selectedDiscount!)
        : product.price;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Product Image
                if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      product.imageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<DocumentSnapshot>(
                        future: product.categoryRef.get(),
                        builder: (context, snapshot) {
                          final categoryName =
                              snapshot.hasData ? snapshot.data?.get('name') ?? '' : 'Loading...';
                          return Text(
                            'Category: $categoryName',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          );
                        },
                      ),
                      if (product.barcode.isNotEmpty)
                        Text(
                          'Barcode: ${product.barcode}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),

                // Remove Button
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),

            const Divider(height: 24),

            // Discount Dropdown
            if (applicableDiscounts.isNotEmpty) ...[
              Text(
                'Available Discounts:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<Discount>(
                  isExpanded: true,
                  value: _selectedDiscount,
                  hint: const Text('Select discount...'),
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem<Discount>(
                      value: null,
                      child: Text('No discount'),
                    ),
                    ...applicableDiscounts.map(
                      (discount) => DropdownMenuItem<Discount>(
                        value: discount,
                        child: Text(
                          '${discount.value}${discount.type} discount',
                          style: TextStyle(
                            color: _selectedDiscount == discount
                                ? Theme.of(context).primaryColor
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (Discount? selected) {
                    setState(() {
                      _selectedDiscount = selected;
                    });
                    salesVM.selectDiscountForCartItem(widget.cartItem.id, selected);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Price Display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Final Price:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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

            if (_selectedDiscount != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Original: €${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),

            if (_selectedDiscount != null) ...[
              const SizedBox(height: 12),
              DiscountBadge(discount: _selectedDiscount!),
            ],
          ],
        ),
      ),
    );
  }

  double _calculatePriceWithDiscount(double basePrice, Discount discount) {
    return discount.type == '%'
        ? basePrice * (1 - discount.value / 100)
        : basePrice - discount.value;
  }
}
