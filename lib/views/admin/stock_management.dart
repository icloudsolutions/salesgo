import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:salesgo/viewmodels/auth_vm.dart';


class StockManagement extends StatefulWidget {
  const StockManagement({super.key});

  @override
  _StockManagementState createState() => _StockManagementState();
}

class _StockManagementState extends State<StockManagement> {
  String? _selectedLocationId;
  final _formKey = GlobalKey<FormState>();
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _selectedProduct;
  bool _isScanning = false;
  bool _isProcessingBarcode = false; // Prevent duplicate scans
  late MobileScannerController _scannerController;
  bool _isLoadingProducts = true; // Track product loading state

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _loadProducts();
  }

  @override
  void dispose() {
    _productController.dispose();
    _quantityController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .get();
      
      if (mounted) {
        setState(() {
          _products = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unknown Product',
              'barcode': data['barcode'] ?? '',
              'category': data['category'] ?? '',
            };
          }).toList();
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load products: ${e.toString()}')),
        );
      }
    }
  }

  void _toggleScanning() {
    if (_isProcessingBarcode) return;
    
    setState(() {
      _isScanning = !_isScanning;
      if (_isScanning) {
        _scannerController.start();
      } else {
        _scannerController.stop();
      }
    });
  }

  void _handleBarcodeScan(BarcodeCapture capture) {
    if (_isProcessingBarcode || capture.barcodes.isEmpty) return;
    
    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() => _isProcessingBarcode = true);

    try {
      // Find product in preloaded data
      final product = _products.firstWhere(
        (p) => p['barcode'] == barcode,
        orElse: () => {},
      );

      if (mounted) {
        if (product.isNotEmpty) {
          setState(() {
            _selectedProduct = product;
            _productController.text = '${product['name']} (${product['barcode']})';
            _isScanning = false;
          });
          _scannerController.stop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not found for this barcode')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing barcode: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingBarcode = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        actions: [
          IconButton(
            icon: _isScanning 
                ? const Icon(Icons.cancel, color: Colors.red)
                : const Icon(Icons.qr_code_scanner),
            onPressed: _isProcessingBarcode ? null : _toggleScanning,
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Scanner overlay
                if (_isScanning)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: _handleBarcodeScan,
                        ),
                        if (_isProcessingBarcode)
                          const Center(
                            child: CircularProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                if (_isScanning) const SizedBox(height: 16),
                
                // Location Selection Dropdown
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('locations').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    
                    return DropdownButtonFormField<String>(
                      value: _selectedLocationId,
                      decoration: const InputDecoration(
                        labelText: 'Select Location',
                        border: OutlineInputBorder(),
                      ),
                      items: snapshot.data!.docs.map((doc) {
                        final location = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text('${location['name']} (${location['type']})'),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedLocationId = value),
                      validator: (value) => value == null ? 'Please select a location' : null,
                    );
                  },
                ),
                const SizedBox(height: 20),
                
                // Stock Assignment Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Autocomplete<Map<String, dynamic>>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }
                          return _products.where((product) => 
                            product['name'].toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                            (product['barcode']?.toString() ?? '').contains(textEditingValue.text)
                          );
                        },
                        onSelected: (Map<String, dynamic> selection) {
                          setState(() {
                            _selectedProduct = selection;
                            _productController.text = '${selection['name']} (${selection['barcode']})';
                          });
                        },
                        displayStringForOption: (Map<String, dynamic> option) => 
                          '${option['name']} (${option['barcode']})',
                        fieldViewBuilder: (
                          BuildContext context,
                          TextEditingController textEditingController,
                          FocusNode focusNode,
                          VoidCallback onFieldSubmitted,
                        ) {
                          // Sync the internal controller with our _productController
                          _productController.addListener(() {
                            if (_productController.text != textEditingController.text) {
                              textEditingController.text = _productController.text;
                            }
                          });

                          return TextFormField(
                            controller: textEditingController, // Use the Autocomplete's controller
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Search Product',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a product';
                              }
                              return null;
                            },
                          );
                        },
                        optionsViewBuilder: (
                          BuildContext context,
                          AutocompleteOnSelected<Map<String, dynamic>> onSelected,
                          Iterable<Map<String, dynamic>> options,
                        ) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final product = options.elementAt(index);
                                    return InkWell(
                                      onTap: () {
                                        onSelected(product);
                                        _productController.text = '${product['name']} (${product['barcode']})';
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product['name'],
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            Text('Barcode: ${product['barcode']}'),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter quantity';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _assignStock,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Assign Stock'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                
                // Stock History Section (Admin Only)
                if (authVM.userRole == 'admin')
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Stock History',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('stockHistory')
                                .orderBy('timestamp', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              
                              return ListView.builder(
                                itemCount: snapshot.data!.docs.length,
                                itemBuilder: (context, index) {
                                  final doc = snapshot.data!.docs[index];
                                  final data = doc.data() as Map<String, dynamic>;
                                  
                                  return FutureBuilder(
                                    future: Future.wait([
                                      FirebaseFirestore.instance
                                          .collection('locations')
                                          .doc(data['locationId'])
                                          .get(),
                                      FirebaseFirestore.instance
                                          .collection('products')
                                          .doc(data['productId'])
                                          .get(),
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(data['adminId'])
                                          .get(),
                                    ]),
                                    builder: (context, AsyncSnapshot<List<DocumentSnapshot>> snapshot) {
                                      if (!snapshot.hasData) {
                                        return const ListTile(
                                          title: Text('Loading...'),
                                        );
                                      }
                                      
                                      final location = snapshot.data![0].data() as Map<String, dynamic>? ?? {};
                                      final product = snapshot.data![1].data() as Map<String, dynamic>? ?? {};
                                      final admin = snapshot.data![2].data() as Map<String, dynamic>? ?? {};
                                      
                                      return Card(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        child: ListTile(
                                          title: Text(product['name'] ?? 'Unknown Product'),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Location: ${location['name']} (${location['type']})'),
                                              Text('Quantity: ${data['quantity']}'),
                                              Text('Admin: ${admin['email']}'),
                                            ],
                                          ),
                                          trailing: Text(
                                            DateFormat('dd/MM/yy HH:mm').format(
                                              (data['timestamp'] as Timestamp).toDate(),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoadingProducts)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Future<void> _assignStock() async {
    if (_selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final productId = _selectedProduct!['id'];
      final quantity = int.parse(_quantityController.text);
      final authVM = Provider.of<AuthViewModel>(context, listen: false);

      try {
        // Verify admin role before proceeding
        if (authVM.userRole != 'admin') {
          throw Exception('Only administrators can assign stock');
        }

        // Use batch write for atomic operations
        final batch = FirebaseFirestore.instance.batch();

        // 1. Update stock quantity
        final stockRef = FirebaseFirestore.instance
            .collection('locations')
            .doc(_selectedLocationId)
            .collection('stock')
            .doc(productId);
        batch.set(stockRef, {
          'quantity': quantity,
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': authVM.currentUser?.uid,
        });

        // 2. Add to stock history
        final historyRef = FirebaseFirestore.instance
            .collection('stockHistory')
            .doc();
        batch.set(historyRef, {
          'locationId': _selectedLocationId,
          'productId': productId,
          'productName': _selectedProduct!['name'], // Added product name for better tracking
          'previousQuantity': FieldValue.increment(0), // Placeholder if you want to track changes
          'quantity': quantity,
          'timestamp': FieldValue.serverTimestamp(),
          'adminId': authVM.currentUser?.uid,
          'adminName': authVM.currentUser?.name ?? 'Admin',
        });

        // Execute both operations atomically
        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock updated successfully')),
        );

        // Clear form
        _productController.clear();
        _quantityController.clear();
        setState(() => _selectedProduct = null);
        FocusScope.of(context).unfocus();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating stock: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

}