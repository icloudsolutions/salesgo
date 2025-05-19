import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesgo/models/product.dart';
import 'package:salesgo/viewmodels/refund_vm.dart';
import 'package:salesgo/widgets/product_picker_dialog.dart';

class RefundScreen extends StatefulWidget {
  const RefundScreen({super.key});

  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late RefundViewModel refundVM;
  String reason = '';
  String? selectedLocationId;
  String? selectedAgentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    refundVM = Provider.of<RefundViewModel>(context, listen: false);
  }

  void _processRefund() async {
    try {
      await refundVM.processRefund(
        agentId: selectedAgentId ?? '',
        locationId: selectedLocationId ?? '',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund completed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refund failed: $e')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final refundVM = Provider.of<RefundViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Refund & Exchange"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Refund"),
            Tab(text: "Exchange"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRefundTab(refundVM),
          _buildExchangeTab(refundVM),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ElevatedButton(
          onPressed: _processRefund,
          child: const Text('Submit'),
        ),
      ),
    );
  }

  Widget _buildRefundTab(RefundViewModel vm) {
    return ListView.builder(
      itemCount: vm.refundItems.length,
      itemBuilder: (context, index) {
        final product = vm.refundItems[index];
        return ListTile(
          title: Text(product.name),
          subtitle: Text("Refund: ${product.price.toStringAsFixed(2)}"),
          trailing: IconButton(
            icon: const Icon(Icons.remove_circle),
            onPressed: () => vm.removeFromRefund(index),
          ),
        );
      },
    );
  }

  void _pickProduct(String label, void Function(Product, int) callback) {
    showDialog(
      context: context,
      builder: (_) => ProductPickerDialog(
        title: label,
        onProductSelected: callback,
      ),
    );
  }

  Widget _buildExchangeTab(RefundViewModel vm) {
    return Column(
      children: [
        ListTile(
          title: Text(vm.originalProduct?.name ?? 'Select original product'),
          subtitle: vm.originalProduct != null
              ? Text('Qty: ${vm.originalQty} - \$${(vm.originalProduct!.price * vm.originalQty).toStringAsFixed(2)}')
              : null,
          trailing: const Icon(Icons.search),
          onTap: () {
            _pickProduct('Select Original Product', vm.setOriginalProduct);
          },
        ),
        ListTile(
          title: Text(vm.replacementProduct?.name ?? 'Select replacement product'),
          subtitle: vm.replacementProduct != null
              ? Text('Qty: ${vm.replacementQty} - \$${(vm.replacementProduct!.price * vm.replacementQty).toStringAsFixed(2)}')
              : null,
          trailing: const Icon(Icons.search),
          onTap: () {
            _pickProduct('Select Replacement Product', vm.setReplacementProduct);
          },
        ),
        const Divider(),
        ListTile(
          title: const Text('Price Difference'),
          trailing: Text('${vm.priceDifference.toStringAsFixed(2)}'),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: const InputDecoration(labelText: 'Reason for exchange'),
            onChanged: (value) => reason = value,
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Confirm Exchange'),
          onPressed: () async {
            try {
              await vm.processExchange(
                agentId: selectedAgentId ?? '',
                locationId: selectedLocationId ?? '',
                reason: reason,
              );
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Exchange recorded.")));
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
            }
          },
        )
      ],
    );
  }

}
