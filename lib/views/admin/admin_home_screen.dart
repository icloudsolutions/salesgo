import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesgo/views/admin/car_management.dart';
import 'package:salesgo/views/admin/product_management.dart';
import 'users_screen.dart';
import 'stock_management.dart';
import 'reports_screen.dart';
import '../../viewmodels/auth_vm.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _adminScreens = [
    UsersScreen(),
    ProductManagement(),
    CarManagement(),
    StockManagement(),
    ReportsScreen(),
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
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _adminScreens.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Important for more than 3 items
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Agents',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Produits',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Véhicules',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Rapports',
          ),
        ],
        selectedItemColor: Colors.blue, // Customize as needed
        unselectedItemColor: Colors.grey, // Customize as needed
      ),
    );
  }
}