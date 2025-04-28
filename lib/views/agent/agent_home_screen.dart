import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesgo/viewmodels/auth_vm.dart';
import 'package:salesgo/viewmodels/discount_vm.dart';
import 'package:salesgo/viewmodels/stock_vm.dart';
import 'sales_screen.dart';
import 'stock_screen.dart';
import 'sales_history_screen.dart';

class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize viewmodels when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stockVM = context.read<StockViewModel>();
      final discountVM = context.read<DiscountViewModel>();
      final authVM = context.read<AuthViewModel>();
      
      // Load stock for the assigned location (if any)
      if (authVM.currentUser?.assignedLocationId != null) {
        stockVM.loadStock(authVM.currentUser!.assignedLocationId!);
      }
      
      // Load active discounts
      discountVM.loadActiveDiscounts();
    });
  }

  static const List<Widget> _agentScreens = [
    SalesScreen(),
    StockScreen(),
    HistoryScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _logout(BuildContext context) async {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    await authVM.signOut();
    Navigator.pushReplacementNamed(context, '/');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach Mobile Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _agentScreens.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}