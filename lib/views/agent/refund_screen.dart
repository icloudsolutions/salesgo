import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:salesgo/services/firestore_service.dart';
import 'package:salesgo/viewmodels/auth_vm.dart';
import 'package:salesgo/viewmodels/refund_vm.dart';
import 'package:salesgo/widgets/product_details_card.dart';
import 'package:salesgo/widgets/refund_product_card.dart';

class RefundScreen extends StatefulWidget {
  const RefundScreen({super.key});

  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isScanning = false;
  bool _isProcessingRefund = false;
  bool _hasScanned = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final refundVM = Provider.of<RefundViewModel>(context);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Refund'),
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
              if (_isScanning) _buildScannerSection(context, refundVM),
              Expanded(
                child: ListView.builder(
                  itemCount: refundVM.refundItems.length,
                  itemBuilder: (context, index) => RefundProductCard(
                    product: refundVM.refundItems[index],
                    onRemove: () {
                      refundVM.removeFromRefund(index);
                      if (refundVM.refundItems.isEmpty) {
                        setState(() => _hasScanned = false);
                      }
                    },
                  ),
                ),
              ),
              if (refundVM.refundItems.isNotEmpty)
                _buildRefundControls(context, refundVM, authVM),
            ],
          ),
          if (_isProcessingRefund)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildScannerSection(BuildContext context, RefundViewModel refundVM) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: MobileScanner(
        controller: _scannerController,
        onDetect: (capture) {
          if (!_hasScanned) {
            _handleBarcodeScan(capture, context, refundVM);
          }
        },
      ),
    );
  }

  Widget _buildRefundControls(BuildContext context, RefundViewModel refundVM, AuthViewModel authVM) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Refund:', style: TextStyle(fontSize: 18)),
              Text(
                '€${refundVM.totalRefundAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => refundVM.clearRefund(),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Red color for refund action
                  ),
                  onPressed: () => _processRefund(context, refundVM, authVM),
                  child: const Text('Process Refund'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleBarcodeScan(
    BarcodeCapture capture,
    BuildContext context,
    RefundViewModel refundVM,
  ) async {
    if (capture.barcodes.isEmpty || _hasScanned) return;

    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null) return;

    setState(() {
      _hasScanned = true;
      _isScanning = false;
    });
    _scannerController.stop();

    try {
      final product = await _firestoreService.getProductByBarcode(barcode);
      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product not found')),
        );
        setState(() => _hasScanned = false);
        return;
      }

      refundVM.addToRefund(product);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _hasScanned = false);
    }
  }

  void _toggleScanning() {
    setState(() {
      _isScanning = !_isScanning;
      if (_isScanning) {
        _hasScanned = false;
        _scannerController.start();
      } else {
        _scannerController.stop();
      }
    });
  }

  Future<void> _processRefund(
    BuildContext context,
    RefundViewModel refundVM,
    AuthViewModel authVM,
  ) async {
    if (authVM.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    if (refundVM.refundItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to refund')),
      );
      return;
    }

    setState(() => _isProcessingRefund = true);

    try {
      // Implement your refund logic here
      // Example: await _firestoreService.processRefund(...);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund processed successfully!')),
      );

      refundVM.clearRefund();
      setState(() {
        _isScanning = true;
        _isProcessingRefund = false;
        _hasScanned = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing refund: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingRefund = false);
      }
    }
  }
}