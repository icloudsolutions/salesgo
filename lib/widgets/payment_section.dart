import 'package:flutter/material.dart';

class PaymentSection extends StatefulWidget {
  final Function(String, String?) onConfirm;
  final double totalAmount;

  const PaymentSection({
    super.key,
    required this.onConfirm,
    required this.totalAmount,
  });

  @override
  State<PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends State<PaymentSection> {
  String? _selectedPaymentMethod;
  final _couponController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Total: €${widget.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                value: _selectedPaymentMethod,
                items: const [
                  DropdownMenuItem(
                    value: 'cash',
                    child: Text('Cash'),
                  ),
                  DropdownMenuItem(
                    value: 'card',
                    child: Text('Credit Card'),
                  ),
                  DropdownMenuItem(
                    value: 'mobile',
                    child: Text('Mobile Payment'),
                  ),
                ],
                validator: (value) =>
                    value == null ? 'Please select payment method' : null,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethod = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _couponController,
                decoration: const InputDecoration(
                  labelText: 'Coupon Code (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _handleConfirmation,
                child: const Text('Confirm Sale'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleConfirmation() {
    if (_formKey.currentState!.validate()) {
      widget.onConfirm(
        _selectedPaymentMethod!,
        _couponController.text.isNotEmpty ? _couponController.text : null,
      );
    }
  }
}