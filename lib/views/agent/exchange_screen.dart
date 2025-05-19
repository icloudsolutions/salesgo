import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesgo/models/product.dart';
import 'package:salesgo/viewmodels/auth_vm.dart';
import 'package:salesgo/viewmodels/refund_vm.dart';
import 'package:salesgo/widgets/product_picker_dialog.dart';

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  String reason = '';
  String? selectedAgentId;
  String? selectedLocationId;

  void _pickProduct(String label, void Function(Product, int) callback) {
    showDialog(
      context: context,
      builder: (_) => ProductPickerDialog(
        title: label,
        onProductSelected: callback,
      ),
    );
  }

  void _submitExchange(RefundViewModel vm) async {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    final agentId = selectedAgentId ?? authVM.currentUser?.uid;
    final locationId = selectedLocationId ?? authVM.currentUser?.assignedLocationId;

    print('agentId: $agentId');
    print('locationId: $locationId');

    if (agentId == null || locationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agent and location are required.")),
      );
      return;
    }

    try {
      await vm.processExchange(
        agentId: agentId,
        locationId: locationId,
        reason: reason,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Exchange successfully recorded.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final refundVM = Provider.of<RefundViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Product Exchange"),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: refundVM.clearExchange,
            tooltip: "Reset Exchange",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              title: Text(refundVM.originalProduct?.name ?? 'Select original product'),
              subtitle: refundVM.originalProduct != null
                  ? Text('Qty: ${refundVM.originalQty} - \$${(refundVM.originalProduct!.price * refundVM.originalQty).toStringAsFixed(2)}')
                  : null,
              trailing: const Icon(Icons.search),
              onTap: () => _pickProduct("Select Original Product", refundVM.setOriginalProduct),
            ),
            const SizedBox(height: 10),
            ListTile(
              title: Text(refundVM.replacementProduct?.name ?? 'Select replacement product'),
              subtitle: refundVM.replacementProduct != null
                  ? Text('Qty: ${refundVM.replacementQty} - \$${(refundVM.replacementProduct!.price * refundVM.replacementQty).toStringAsFixed(2)}')
                  : null,
              trailing: const Icon(Icons.search),
              onTap: () => _pickProduct("Select Replacement Product", refundVM.setReplacementProduct),
            ),
            const Divider(height: 30),
            ListTile(
              title: const Text("Price Difference"),
              trailing: Text(
                '${refundVM.priceDifference >= 0 ? '+' : ''}${refundVM.priceDifference.toStringAsFixed(2)}',
                style: TextStyle(
                  color: refundVM.priceDifference > 0
                      ? Colors.red
                      : refundVM.priceDifference < 0
                          ? Colors.green
                          : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                labelText: "Reason for exchange",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (value) => setState(() => reason = value),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _submitExchange(refundVM),
              icon: const Icon(Icons.check),
              label: const Text("Confirm Exchange"),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
    );
  }
}
