import 'package:flutter/material.dart';
import '../models/discount.dart';

class DiscountBadge extends StatelessWidget {
  final Discount discount;
  
  const DiscountBadge({super.key, required this.discount});

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: discount.type == '%' ? Colors.amber[100] : Colors.green[100],
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${discount.value}${discount.type}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: discount.type == '%' ? Colors.orange[800] : Colors.green[800],
            ),
          ),
          Text(
            'Valide: ${discount.startDate?.day}/${discount.startDate?.month} '
            '- ${discount.endDate?.day}/${discount.endDate?.month}',
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}