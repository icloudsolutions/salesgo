import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des Stocks')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('cars').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                
                return DropdownButton<String>(
                  value: _selectedCarId,
                  hint: const Text('Sélectionner une voiture'),
                  items: snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(doc.id),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedCarId = value),
                );
              },
            ),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _productController,
                    decoration: const InputDecoration(labelText: 'Produit ID'),
                    validator: (value) => value!.isEmpty ? 'Requis' : null,
                  ),
                  TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantité'),
                    validator: (value) => value!.isEmpty ? 'Requis' : null,
                  ),
                  ElevatedButton(
                    child: const Text('Assigner Stock'),
                    onPressed: _assignStock,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _assignStock() async {
    if (_selectedCarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a car')));
      return;
    }
    
    if (_formKey.currentState!.validate()) {
      // Verify product exists
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(_productController.text)
          .get();

      if (!productDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product does not exist')));
        return;
      }

      // Update stock
      await FirebaseFirestore.instance
          .collection('cars/$_selectedCarId/stock')
          .doc(_productController.text)
          .set({'quantity': int.parse(_quantityController.text)});
    }
  }
}