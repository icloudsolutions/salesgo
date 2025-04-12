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
  bool _hasScanned = false; // New flag to track if we've scanned a product

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
        title: const Text('Quick Sale'),
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
                    onRemove: () {
                      salesVM.removeFromCart(index);
                      // Reset scan state when product is removed
                      if (salesVM.cartItems.isEmpty) {
                        setState(() {
                          _hasScanned = false;
                        });
                      }
                    },
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
        onDetect: (capture) {
          if (!_hasScanned) { // Only scan if we haven't already scanned a product
            _handleBarcodeScan(capture, context, salesVM);
          }
        },
      ),
    );
  }

  void _handleBarcodeScan(
    BarcodeCapture capture,
    BuildContext context,
    SalesViewModel salesVM,
  ) async {
    if (capture.barcodes.isEmpty || _hasScanned) return; // Prevent multiple scans

    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null) return;

    setState(() {
      _hasScanned = true; // Ensure scanning stops
      _isScanning = false;
    });
    _scannerController.stop(); // Stop scanning immediately

    try {
      final product = await _firestoreService.getProductByBarcode(barcode);
      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product not found')),
        );
        setState(() => _hasScanned = false); // Allow scanning again if product is not found
        return;
      }

      salesVM.addToCart(product);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _hasScanned = false); // Allow re-scanning in case of error
    }
  }


  void _toggleScanning() {
    setState(() {
      _isScanning = !_isScanning;
      if (_isScanning) {
        _hasScanned = false; // Reset scanning state when re-enabling scanner
        _scannerController.start();
      } else {
        _scannerController.stop();
      }
    });
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
      setState(() {
        _isScanning = true;
        _isProcessingPayment = false;
        _hasScanned = false; // Reset scan state for new sale
      });
      _scannerController.start();
      
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