import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:salesgo/services/firestore_service.dart';
import 'package:salesgo/viewmodels/auth_vm.dart';
import 'package:salesgo/viewmodels/sales_vm.dart';
import 'package:salesgo/widgets/product_details_card.dart';
import 'package:salesgo/widgets/payment_section.dart';
import 'package:salesgo/views/agent/sales_history_screen.dart';
import 'package:salesgo/viewmodels/refund_vm.dart';
import 'package:salesgo/widgets/refund_product_card.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isScanning = false;
  bool _isProcessingPayment = false;
  bool _hasScanned = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scannerController.stop(); // Ensure scanner is stopped initially
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salesVM = Provider.of<SalesViewModel>(context);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Sale'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_cart)),
            Tab(icon: Icon(Icons.history)),
            Tab(icon: Icon(Icons.assignment_return)),
          ],
        ),
        actions: [
          if (_tabController.index == 0) // Only show scanner toggle on sales tab
            IconButton(
              icon: Icon(_isScanning ? Icons.no_photography : Icons.qr_code_scanner),
              onPressed: _toggleScanning,
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Sales Tab
          _buildSalesTab(context, salesVM, authVM),
          
          // History Tab
          const HistoryScreen(),
          
          // Refund Tab
          _buildRefundTab(),
        ],
      ),
    );
  }

  Widget _buildSalesTab(BuildContext context, SalesViewModel salesVM, AuthViewModel authVM) {
    return Stack(
      children: [
        Column(
          children: [
            if (_isScanning) _buildScannerSection(context, salesVM),
            if (salesVM.cartItems.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 20),
                      Text(
                        _isScanning ? 'Scanning in progress' : 'Ready to Process Sale',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isScanning ? 'Point camera at barcode' : 'Scan products to add to cart',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: Icon(_isScanning ? Icons.stop : Icons.qr_code_scanner),
                        label: Text(_isScanning ? 'Stop Scanning' : 'Start Scanning'),
                        onPressed: _toggleScanning,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isScanning ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (salesVM.cartItems.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: salesVM.cartItems.length,
                  itemBuilder: (context, index) => ProductDetailsCard(
                    cartItem: salesVM.cartItems[index],
                    onRemove: () {
                      salesVM.removeFromCart(index);
                      if (salesVM.cartItems.isEmpty) {
                        setState(() => _hasScanned = false);
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
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildRefundTab() {
    return Consumer<AuthViewModel>(
      builder: (context, authVM, _) {
        if (authVM.currentUser == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text('Authentication Required', style: TextStyle(fontSize: 20)),
                SizedBox(height: 8),
                Text('Please login to process refunds', 
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return Consumer<RefundViewModel>(
          builder: (context, refundVM, _) {
            if (refundVM.refundItems.isEmpty) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_return, 
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text('Ready to Process Refund',
                      style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 10),
                  const Text('Scan products to refund',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Start Scanning'),
                    onPressed: () {
                      // No need to navigate, we'll show the scanner in this tab
                      refundVM.clearRefund();
                      // You might want to set a state to show the scanner here
                    },
                  ),
                ],
              );
            }

            return Column(
              children: [
                // Your scanner widget when active
                // Your refund items list
                Expanded(
                  child: ListView.builder(
                    itemCount: refundVM.refundItems.length,
                    itemBuilder: (context, index) => RefundProductCard(
                      product: refundVM.refundItems[index],
                      onRemove: () => refundVM.removeFromRefund(index),
                    ),
                  ),
                ),

                // Refund summary and action buttons
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Refund:', 
                              style: TextStyle(fontSize: 18)),
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
                              onPressed: refundVM.clearRefund,
                              child: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => _processRefund(context, refundVM, authVM),
                              child: const Text('Process Refund'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _processRefund(
    BuildContext context,
    RefundViewModel refundVM,
    AuthViewModel authVM,
  ) async {
    if (refundVM.refundItems.isEmpty) return;

    try {
      await refundVM.processRefund(
        agentId: authVM.currentUser!.uid,
        locationId: authVM.currentUser!.assignedLocationId!,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund processed successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing refund: $e')),
      );
    }
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
          if (!_hasScanned) {
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

      salesVM.addToCart(product);
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
        locationId: authVM.currentUser!.assignedLocationId!, 
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale completed successfully!')),
      );

      setState(() {
        _isScanning = true;
        _isProcessingPayment = false;
        _hasScanned = false;
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