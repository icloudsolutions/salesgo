import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_vm.dart';
import '../../models/product.dart';

class StockManagement extends StatefulWidget {
  const StockManagement({super.key});

  @override
  _StockManagementState createState() => _StockManagementState();
}

class _StockManagementState extends State<StockManagement> {
  String? _selectedCarId;
  final _formKey = GlobalKey<FormState>();
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final snapshot = await FirebaseFirestore.instance.collection('products').get();
    setState(() {
      _products = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Product',
          'category': data['category'] ?? '',
        };
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Car Selection Dropdown
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('cars').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                
                return DropdownButtonFormField<String>(
                  value: _selectedCarId,
                  decoration: const InputDecoration(
                    labelText: 'Select Car',
                    border: OutlineInputBorder(),
                  ),
                  items: snapshot.data!.docs.map((doc) {
                    final car = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text('${car['name']} (${car['plateNumber']})'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedCarId = value),
                  validator: (value) => value == null ? 'Please select a car' : null,
                );
              },
            ),
            const SizedBox(height: 20),
            
            // Stock Assignment Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return _products
                          .where((product) => product['name']
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()))
                          .map((product) => product['id']);
                    },
                    onSelected: (String selection) {
                      _productController.text = selection;
                    },
                    fieldViewBuilder: (
                      BuildContext context,
                      TextEditingController textEditingController,
                      FocusNode focusNode,
                      VoidCallback onFieldSubmitted,
                    ) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Search Product',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                    optionsViewBuilder: (
                      BuildContext context,
                      AutocompleteOnSelected<String> onSelected,
                      Iterable<String> options,
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
                                final option = options.elementAt(index);
                                final product = _products.firstWhere(
                                  (p) => p['id'] == option,
                                  orElse: () => {'name': 'Unknown'},
                                );
                                return InkWell(
                                  onTap: () {
                                    onSelected(option);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(product['name']),
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
                                      .collection('cars')
                                      .doc(data['carId'])
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
                                  
                                  final car = snapshot.data![0].data() as Map<String, dynamic>? ?? {};
                                  final product = snapshot.data![1].data() as Map<String, dynamic>? ?? {};
                                  final admin = snapshot.data![2].data() as Map<String, dynamic>? ?? {};
                                  
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      title: Text(product['name'] ?? 'Unknown Product'),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Car: ${car['name']} (${car['plateNumber']})'),
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
    );
  }

  Future<void> _assignStock() async {
    if (_selectedCarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a car')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final productId = _productController.text;
      final quantity = int.parse(_quantityController.text);
      final authVM = Provider.of<AuthViewModel>(context, listen: false);

      try {
        // Verify product exists
        final productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .get();

        if (!productDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product does not exist')),
          );
          return;
        }

        // Update stock
        await FirebaseFirestore.instance
            .collection('cars/$_selectedCarId/stock')
            .doc(productId)
            .set({'quantity': quantity});

        // Record history if admin
        if (authVM.userRole == 'admin') {
          await FirebaseFirestore.instance.collection('stockHistory').add({
            'carId': _selectedCarId,
            'productId': productId,
            'quantity': quantity,
            'timestamp': DateTime.now(),
            'adminId': authVM.currentUser?.uid,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock updated successfully')),
        );

        // Clear form
        _productController.clear();
        _quantityController.clear();
        FocusScope.of(context).requestFocus(FocusNode());
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating stock: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _productController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}