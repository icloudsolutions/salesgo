import 'package:flutter/material.dart';
import 'package:salesgo/models/product.dart';
import 'package:salesgo/services/firestore_service.dart';

class StockSettingsForm extends StatefulWidget {
  final Product product;

  StockSettingsForm({required this.product});

  @override
  _StockSettingsFormState createState() => _StockSettingsFormState();
}

class _StockSettingsFormState extends State<StockSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late bool _trackStock;
  late TextEditingController _minStockController;

  @override
  void initState() {
    super.initState();
    _trackStock = widget.product.trackStock;
    _minStockController = TextEditingController(
      text: widget.product.minStockLevel.toStringAsFixed(2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Stock Settings'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Track Stock'),
              value: _trackStock,
              onChanged: (value) => setState(() => _trackStock = value),
            ),
            if (_trackStock)
              TextFormField(
                controller: _minStockController,
                decoration: InputDecoration(
                  labelText: 'Minimum Stock Level',
                  suffixText: 'units',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (_trackStock && (value == null || value.isEmpty)) {
                    return 'Required when stock tracking is enabled';
                  }
                  return null;
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveSettings,
          child: Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirestoreService().updateProductStockSettings(
          widget.product.copyWith(
            trackStock: _trackStock,
            minStockLevel: _trackStock 
              ? double.parse(_minStockController.text)
              : 0,
          ),
        );
        Navigator.pop(context, true); // Return success
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: ${e.toString()}')),
        );
      }
    }
  }
}