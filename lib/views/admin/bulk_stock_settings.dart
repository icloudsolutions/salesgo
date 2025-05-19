import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:salesgo/models/product.dart';
import 'package:salesgo/services/firestore_service.dart' show FirestoreService;

class BulkStockSettingsScreen extends StatefulWidget {
  @override
  _BulkStockSettingsScreenState createState() => _BulkStockSettingsScreenState();
}

class _BulkStockSettingsScreenState extends State<BulkStockSettingsScreen> {
  final Map<String, double> _updates = {};
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bulk Stock Settings')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getProductsNeedingRestock(),
        builder: (context, snapshot) {
          // Build editable list of products
          return ListView.builder(
            itemCount: snapshot.data?.docs.length ?? 0,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final product = Product.fromFirestore(doc);

              return ListTile(
                title: Text(product.name),
                subtitle: Text('Current min: ${product.minStockLevel}'),
                trailing: SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: product.minStockLevel.toStringAsFixed(2),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _updates[product.id] = 
                      double.tryParse(value) ?? product.minStockLevel,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.save),
        onPressed: () async {
          try {
            await _firestoreService.bulkUpdateMinStockLevel(_updates);
            Navigator.pop(context);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving: ${e.toString()}')),
            );
          }
        },
      ),
    );
  }
}