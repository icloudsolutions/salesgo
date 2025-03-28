import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:salesgo/services/firestore_service.dart';
import 'package:salesgo/viewmodels/auth_vm.dart';
import 'package:salesgo/viewmodels/sales_vm.dart';
import 'package:salesgo/widgets/product_details_card.dart';
import 'package:salesgo/widgets/payment_section.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isScanning = true;
  bool _isProcessingPayment = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salesVM = Provider.of<SalesViewModel>(context);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.no_photography : Icons.qr_code_scanner),
            onPressed: _toggleScanning,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_isScanning) _buildScannerSection(context, salesVM),
              Expanded(
                child: ListView.builder(
                  itemCount: salesVM.cartItems.length,
                  itemBuilder: (context, index) => ProductDetailsCard(
                    product: salesVM.cartItems[index],
                    onRemove: () => salesVM.removeFromCart(index),
                  ),
                ),
              ),
              if (salesVM.cartItems.isNotEmpty)
                PaymentSection(
                  onConfirm: (method, coupon) => _handleSaleConfirmation(
                    context,
                    salesVM,
                    authVM,
                    method,
                    coupon,
                  ),
                  totalAmount: salesVM.totalAmount,
                  isProcessing: _isProcessingPayment,
                ),
            ],
          ),
          if (_isProcessingPayment)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerSection(BuildContext context, SalesViewModel salesVM) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: MobileScanner(
        controller: _scannerController,
        onDetect: (capture) => _handleBarcodeScan(capture, context, salesVM),
      ),
    );
  }

  void _handleBarcodeScan(
    BarcodeCapture capture,
    BuildContext context,
    SalesViewModel salesVM,
  ) async {
    if (capture.barcodes.isEmpty) return;
    
    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null) return;

    try {
      final product = await _firestoreService.getProductByBarcode(barcode);
      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product not found')),
        );
        return;
      }
      salesVM.addToCart(product);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _toggleScanning() {
    setState(() => _isScanning = !_isScanning);
    if (_isScanning) {
      _scannerController.start();
    } else {
      _scannerController.stop();
    }
  }

  Future<void> _handleSaleConfirmation(
    BuildContext context,
    SalesViewModel salesVM,
    AuthViewModel authVM,
    String paymentMethod,
    String? couponCode,
  ) async {
    if (authVM.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      await salesVM.confirmSale(
        paymentMethod: paymentMethod,
        couponCode: couponCode,
        agentId: authVM.currentUser!.uid,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale completed successfully!')),
      );

      // Reset the screen after successful payment
      _scannerController.start();
      setState(() {
        _isScanning = true;
        _isProcessingPayment = false;
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing sale: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }
}