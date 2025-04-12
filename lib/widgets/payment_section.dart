import 'package:flutter/material.dart';

class PaymentSection extends StatefulWidget {
  final Function(String, String?) onConfirm;
  final double totalAmount;
  final bool isProcessing;

  const PaymentSection({
    Key? key,
    required this.onConfirm,
    required this.totalAmount,
    required this.isProcessing,
  }) : super(key: key);

  @override
  State<PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends State<PaymentSection> {
  String? _selectedPaymentMethod;
  final _couponController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void didUpdateWidget(covariant PaymentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset submitting state if parent widget changes processing state
    if (oldWidget.isProcessing && !widget.isProcessing) {
      _isSubmitting = false;
    }
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: AbsorbPointer(
        absorbing: widget.isProcessing || _isSubmitting,
        child: AnimatedOpacity(
          opacity: (widget.isProcessing || _isSubmitting) ? 0.6 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Total: ${widget.totalAmount.toStringAsFixed(2)} TND',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Payment Method*',
                      border: const OutlineInputBorder(),
                      filled: widget.isProcessing || _isSubmitting,
                      fillColor: Colors.grey[100],
                    ),
                    value: _selectedPaymentMethod,
                    items: const [
                      DropdownMenuItem(
                        value: 'cash',
                        child: Text('Cash'),
                      ),
                      DropdownMenuItem(
                        value: 'TPE',
                        child: Text('TPE'),
                      ),
                      DropdownMenuItem(
                        value: 'Prepayment',
                        child: Text('Prepayment'),
                      ),
                    ],
                    validator: (value) =>
                        value == null ? 'Please select payment method' : null,
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _selectedPaymentMethod = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _couponController,
                    decoration: InputDecoration(
                      labelText: 'Coupon Code (optional)',
                      border: const OutlineInputBorder(),
                      filled: widget.isProcessing || _isSubmitting,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    onPressed: _isSubmitting ? null : _handleConfirmation,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Confirm Sale',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleConfirmation() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onConfirm(
        _selectedPaymentMethod!,
        _couponController.text.trim().isNotEmpty
            ? _couponController.text.trim()
            : null,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}