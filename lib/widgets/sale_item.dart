import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';

class SaleItem extends StatelessWidget {
  final Sale sale;
  final Widget? trailing;
  final VoidCallback? onRefund;

  const SaleItem({
    super.key, 
    required this.sale, 
    this.trailing,
    this.onRefund,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yy HH:mm');
    final currencyFormat = NumberFormat.currency(
      symbol: '€', 
      decimalDigits: 2,
      locale: 'en_EN',
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showSaleDetails(context, sale),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Vente #${sale.id.substring(0, 6)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (sale.refunded) _buildRefundedBadge(),
                ],
              ),
              
              const SizedBox(height: 10),
              
              // Details Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateFormat.format(sale.date),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sale.products.length} ${sale.products.length == 1 ? 'article' : 'articles'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormat.format(sale.totalAmount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildPaymentMethodChip(sale.paymentMethod),
                    ],
                  ),
                ],
              ),
              
              // Refund Section
              if (sale.refunded && sale.refundDate != null) 
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Remboursé le ${dateFormat.format(sale.refundDate!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              
              // Action Buttons
              if (trailing != null && !sale.refunded)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: trailing,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefundedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_return, color: Colors.red[400], size: 16),
          const SizedBox(width: 4),
          Text(
            'Remboursé',
            style: TextStyle(
              color: Colors.red[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChip(String method) {
    return Chip(
      label: Text(
        _getPaymentMethodLabel(method),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: _getPaymentMethodColor(method),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  String _getPaymentMethodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'ESPÈCES';
      case 'credit card':
        return 'CARTE';
      case 'mobile payment':
        return 'MOBILE';
      default:
        return method.toUpperCase();
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Colors.green[600]!;
      case 'credit card':
        return Colors.blue[600]!;
      case 'mobile payment':
        return Colors.purple[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  void _showSaleDetails(BuildContext context, Sale sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails de la vente #${sale.id.substring(0, 6)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(sale.date)}'),
              Text('Total: ${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(sale.totalAmount)}'),
              Text('Méthode: ${sale.paymentMethod}'),
              if (sale.refunded) 
                Text('Remboursé le: ${DateFormat('dd/MM/yyyy HH:mm').format(sale.refundDate!)}'),
              
              const SizedBox(height: 16),
              const Text('Articles:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...sale.products.map((product) => 
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: product.imageUrl != null 
                    ? Image.network(product.imageUrl!, width: 40, height: 40)
                    : const Icon(Icons.shopping_bag),
                  title: Text(product.name),
                  subtitle: Text('${product.price}€'),
                )
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}