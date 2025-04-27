import 'package:flutter/material.dart';
import 'package:salesgo/views/admin/admin_home_screen.dart';
import 'package:salesgo/views/admin/users_management.dart';
import 'package:salesgo/views/agent/agent_home_screen.dart';
import 'package:salesgo/views/agent/history_screen.dart';
import 'package:salesgo/views/agent/stock_screen.dart';
import 'package:salesgo/views/login_screen.dart';
import 'widgets/role_based_ui.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile SalesGo',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => const RoleBasedUI(),
        '/login': (context) => const LoginScreen(),
        '/history': (context) => const HistoryScreen(),
        '/stock': (context) => const StockScreen(),
        '/users': (context) => const UsersScreen(),
        '/admin': (context) => const AdminHomeScreen(),
        '/agent': (context) => const AgentHomeScreen(),
      },
    );
  }
}