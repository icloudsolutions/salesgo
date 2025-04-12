import 'package:flutter/material.dart';
import '../models/sale.dart';

class SaleItem extends StatelessWidget {
  final Sale sale;
  
  const SaleItem({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('Vente #${sale.id}'),
        subtitle: Text('Total: ${sale.totalAmount} TND'),
        trailing: Text(sale.paymentMethod),
      ),
    );
  }
}