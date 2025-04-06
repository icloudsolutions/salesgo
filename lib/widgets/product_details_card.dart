import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/discount.dart';
import 'discount_badge.dart';
import '../viewmodels/discount_vm.dart';
import '../viewmodels/sales_vm.dart';
import 'package:provider/provider.dart';

class ProductDetailsCard extends StatefulWidget {
  final Product product;
  final VoidCallback? onRemove;

  const ProductDetailsCard({
    super.key,
    required this.product,
    this.onRemove,
  });

  @override
  State<ProductDetailsCard> createState() => _ProductDetailsCardState();
}

class _ProductDetailsCardState extends State<ProductDetailsCard> {
  Discount? _selectedDiscount;

  @override
  Widget build(BuildContext context) {
    final discountVM = Provider.of<DiscountViewModel>(context);
    final salesVM = Provider.of<SalesViewModel>(context);

    // Get applicable discounts for this product's category
    final applicableDiscounts = discountVM.activeDiscounts
        .where((d) => d.category == widget.product.category)
        .toList();

    // Get the initially selected discount (if any)
    _selectedDiscount ??= salesVM.getSelectedDiscountForProduct(widget.product.id);

    // Calculate final price based on selected discount
    final finalPrice = _selectedDiscount != null
        ? _calculatePriceWithDiscount(widget.product.price, _selectedDiscount!)
        : widget.product.price;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product header row with image and name
            Row(
              children: [
                // Product Image
                if (widget.product.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.product.imageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (widget.product.imageUrl == null || widget.product.imageUrl!.isEmpty)
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
                        widget.product.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.product.category,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      if (widget.product.barcode.isNotEmpty)
                        Text(
                          'Barcode: ${widget.product.barcode}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                
                // Remove Button (only shown if onRemove callback is provided)
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            
            const Divider(height: 24, thickness: 1),
            
            // Discount Selection
            if (applicableDiscounts.isNotEmpty) ...[
              Text(
                'Available Discounts:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
                  underline: const SizedBox(), // Remove default underline
                  items: [
                    const DropdownMenuItem<Discount>(
                      value: null,
                      child: Text('No discount'),
                    ),
                    ...applicableDiscounts.map((discount) {
                      return DropdownMenuItem<Discount>(
                        value: discount,
                        child: Text(
                          '${discount.value}${discount.type} discount',
                          style: TextStyle(
                            color: _selectedDiscount == discount 
                                ? Theme.of(context).primaryColor 
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (Discount? selected) {
                    setState(() {
                      _selectedDiscount = selected;
                    });
                    salesVM.selectDiscountForProduct(widget.product.id, selected);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Price Information
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Final Price:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
            
            // Original price if discounted
            if (_selectedDiscount != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Original: €${widget.product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
            
            // Discount details if applied
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