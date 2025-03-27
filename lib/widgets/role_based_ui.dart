import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_vm.dart';
import '../views/admin/admin_home_screen.dart';
import '../views/agent/agent_home_screen.dart';
import '../views/login_screen.dart'; // Import added

class RoleBasedUI extends StatelessWidget {
  const RoleBasedUI({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);

    if (authVM.userRole == 'admin') {
      return const AdminHomeScreen();
    } else if (authVM.userRole == 'agent') {
      return const AgentHomeScreen();
    } else if (authVM.currentUser == null) {
      // User is not logged in, navigate to login
      return const LoginScreen();
    } else {
      // User is logged in, but role is still being fetched
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
  }
} 