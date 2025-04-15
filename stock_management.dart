import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/location.dart';
import '../../viewmodels/auth_vm.dart';

class StockManagement extends StatefulWidget {
  const StockManagement({super.key});

  @override
  State<StockManagement> createState() => _StockManagementState();
}

class _StockManagementState extends State<StockManagement> {
  String? _selectedLocationId;
  final _formKey = GlobalKey<FormState>();
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  List<Product> _products = [];
  Product? _selectedProduct;
  bool _isLoading = false;
  List<Location> _locations = [];
  StreamSubscription? _locationsSubscription;
  StreamSubscription? _productsSubscription;
  bool _isInitialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    await _loadLocations();
    await _loadProducts();
    setState(() {
      _isLoading = false;
      _isInitialLoadComplete = true;
    });
  }

  @override
  void dispose() {
    _locationsSubscription?.cancel();
    _productsSubscription?.cancel();
    _productController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final userId = authVM.currentUser?.uid;
    
    if (userId == null) return;

    _locationsSubscription = FirebaseFirestore.instance
        .collection('locations')
        .where('assignedAgentId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _locations = snapshot.docs.map((doc) {
            return Location.fromFirestore(doc.data() as Map<String, dynamic>);
          }).toList();

          // Set initial location if not already set and locations exist
          if (_selectedLocationId == null && _locations.isNotEmpty) {
            _selectedLocationId = _locations.first.id;
          }
        });
      }
    }, onError: (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading locations: $error')),
        );
      }
    });
  }

  Future<void> _loadProducts() async {
    _productsSubscription = FirebaseFirestore.instance
        .collection('products')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _products = snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
        });
      }
    }, onError: (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $error')),
        );
      }
    });
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

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final quantity = int.parse(_quantityController.text);
      final authVM = Provider.of<AuthViewModel>(context, listen: false);

      // Create a batch to perform multiple writes atomically
      final batch = FirebaseFirestore.instance.batch();

      // 1. Update stock at location
      final stockRef = FirebaseFirestore.instance
          .collection('locations')
          .doc(_selectedLocationId)
          .collection('stock')
          .doc(_selectedProduct!.id);
      batch.set(stockRef, {
        'productId': _selectedProduct!.id,
        'quantity': quantity,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // 2. Update the product's available locations
      final productRef = FirebaseFirestore.instance
          .collection('products')
          .doc(_selectedProduct!.id);
      batch.update(productRef, {
        'availableLocations': FieldValue.arrayUnion([_selectedLocationId]),
      });

      // 3. Record in stock history
      final historyRef = FirebaseFirestore.instance
          .collection('stockHistory')
          .doc();
      batch.set(historyRef, {
        'productId': _selectedProduct!.id,
        'locationId': _selectedLocationId,
        'quantity': quantity,
        'adminId': authVM.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock updated successfully')),
      );

      // Clear form
      _productController.clear();
      _quantityController.clear();
      setState(() => _selectedProduct = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating stock: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeData,
          ),
        ],
      ),
      body: _isLoading && !_isInitialLoadComplete
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Location Selection
                    _buildLocationDropdown(authVM),
                    const SizedBox(height: 20),

                    // Product Selection
                    _buildProductAutocomplete(),
                    const SizedBox(height: 16),

                    // Quantity Input
                    _buildQuantityInput(),
                    const SizedBox(height: 20),

                    // Submit Button
                    _buildSubmitButton(),
                    const SizedBox(height: 20),
                    const Divider(),

                    // Current Stock Section
                    _buildCurrentStockSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLocationDropdown(AuthViewModel authVM) {
    if (_locations.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No locations available'),
          if (authVM.currentUser?.assignedLocationId == null)
            const Text(
              'You have not been assigned to any location',
              style: TextStyle(color: Colors.red),
            ),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedLocationId,
      decoration: const InputDecoration(
        labelText: 'Select Location',
        border: OutlineInputBorder(),
      ),
      items: _locations.map((location) {
        return DropdownMenuItem<String>(
          value: location.id,
          child: Text('${location.name} (${location.type})'),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedLocationId = value);
        }
      },
      validator: (value) => value == null ? 'Please select a location' : null,
    );
  }

  Widget _buildProductAutocomplete() {
    return Autocomplete<Product>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Product>.empty();
        }
        return _products.where((product) =>
            product.name.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                ) ||
            product.barcode.contains(textEditingValue.text));
      },
      onSelected: (Product selection) {
        setState(() {
          _selectedProduct = selection;
          _productController.text = selection.name;
        });
      },
      displayStringForOption: (Product option) => option.name,
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextFormField(
          controller: _productController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Search Product',
            border: OutlineInputBorder(),
          ),
          validator: (value) =>
              value == null || value.isEmpty ? 'Please select a product' : null,
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<Product> onSelected,
        Iterable<Product> options,
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
                    onTap: () => onSelected(product),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Barcode: ${product.barcode}'),
                          Text('Category: ${product.category}'),
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
    );
  }

  Widget _buildQuantityInput() {
    return TextFormField(
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
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _assignStock,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Assign Stock'),
    );
  }

  Widget _buildCurrentStockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Stock',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _buildCurrentStockList(),
      ],
    );
  }

  Widget _buildCurrentStockList() {
    if (_selectedLocationId == null) {
      return const Center(child: Text('Select a location to view stock'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('locations')
          .doc(_selectedLocationId)
          .collection('stock')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No stock items at this location'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('products')
                  .doc(data['productId'])
                  .get(),
              builder: (context, productSnapshot) {
                if (!productSnapshot.hasData) {
                  return const ListTile(
                    title: Text('Loading...'),
                    leading: CircularProgressIndicator(),
                  );
                }

                final product = Product.fromFirestore(productSnapshot.data!);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: product.imageUrl != null
                        ? Image.network(product.imageUrl!, width: 50, height: 50)
                        : const Icon(Icons.shopping_bag),
                    title: Text(product.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quantity: ${data['quantity']}'),
                        Text('Barcode: ${product.barcode}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('€${product.price.toStringAsFixed(2)}'),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeStock(doc.id, product.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _removeStock(String stockDocId, String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: const Text('Are you sure you want to remove this stock item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    
    try {
      // Create a batch to perform multiple writes atomically
      final batch = FirebaseFirestore.instance.batch();

      // 1. Remove from location's stock
      final stockRef = FirebaseFirestore.instance
          .collection('locations')
          .doc(_selectedLocationId)
          .collection('stock')
          .doc(stockDocId);
      batch.delete(stockRef);

      // 2. Update product's available locations
      final productRef = FirebaseFirestore.instance
          .collection('products')
          .doc(productId);
      batch.update(productRef, {
        'availableLocations': FieldValue.arrayRemove([_selectedLocationId]),
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock item removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing stock: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}