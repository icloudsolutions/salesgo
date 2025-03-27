import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:salesgo/models/sale.dart';
import '../../viewmodels/auth_vm.dart';
import '../../widgets/sale_item.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'week';
  late DateTimeRange _dateRange;

  @override
  void initState() {
    super.initState();
    _updateDateRange();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'day':
        _dateRange = DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: now,
        );
        break;
      case 'week':
        _dateRange = DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
        break;
      case 'month':
        _dateRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
        break;
      default:
        _dateRange = DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final userId = authVM.currentUser?.uid;

    if (userId == null) {
      return const Center(child: Text('User not authenticated'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Ventes'),
        actions: [
          DropdownButton<String>(
            value: _selectedFilter,
            items: const [
              DropdownMenuItem(value: 'day', child: Text('Today')),
              DropdownMenuItem(value: 'week', child: Text('Current Week')),
              DropdownMenuItem(value: 'month', child: Text('Current Month')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedFilter = value;
                  _updateDateRange();
                });
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('sales')
            .where('agentId', isEqualTo: userId)
            .where('date', isGreaterThanOrEqualTo: _dateRange.start)
            .where('date', isLessThanOrEqualTo: _dateRange.end)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucune vente trouvée'));
          }

          final sales = snapshot.data!.docs.map((doc) {
            try {
              return Sale.fromFirestore(doc);
            } catch (e) {
              debugPrint('Error parsing sale: $e');
              return null;
            }
          }).whereType<Sale>().toList();

          return ListView.builder(
            itemCount: sales.length,
            itemBuilder: (context, index) => SaleItem(sale: sales[index]),
          );
        },
      ),
    );
  }
}