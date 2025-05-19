import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesgo/firebase_options.dart';
import 'package:salesgo/viewmodels/discount_vm.dart';
import 'package:salesgo/viewmodels/refund_vm.dart';
import 'package:salesgo/viewmodels/sales_vm.dart';
import 'package:salesgo/viewmodels/stock_vm.dart';
import 'package:salesgo/views/admin/admin_home_screen.dart';
import 'package:salesgo/views/admin/users_management.dart';
import 'package:salesgo/views/agent/agent_home_screen.dart';
import 'package:salesgo/views/agent/exchange_screen.dart';
import 'package:salesgo/views/agent/sales_history_screen.dart';
import 'package:salesgo/views/agent/stock_screen.dart';
import 'package:salesgo/views/signup_screen.dart';
import 'package:salesgo/widgets/role_based_ui.dart';
import 'viewmodels/auth_vm.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'views/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel(authService: FirebaseAuthService())),
        Provider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (context) => SalesViewModel(
          firestoreService: context.read<FirestoreService>(),
        )),
        ChangeNotifierProvider(create: (context) => StockViewModel(
          firestoreService: context.read<FirestoreService>(),
        )),
        ChangeNotifierProvider(create: (context) => DiscountViewModel(
          firestoreService: context.read<FirestoreService>(),
        )),
        ChangeNotifierProvider(create: (context) => RefundViewModel(
          firestoreService: context.read<FirestoreService>(),
        )),        
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authVM, _) {
        return MaterialApp(
          title: 'Ventes Porte-à-Porte',
          theme: ThemeData(primarySwatch: Colors.blue),
          // Remove initialRoute and home, handle everything through routes
          routes: {
            '/': (context) => _buildInitialScreen(authVM),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/history': (context) => const HistoryScreen(),
            '/stock': (context) => const StockScreen(),
            '/users': (context) => const UsersScreen(),
            '/admin': (context) => const AdminHomeScreen(),
            '/agent': (context) => const AgentHomeScreen(),
            '/exchange': (context) => const ExchangeScreen(),
          },
        );
      },
    );
  }

  Widget _buildInitialScreen(AuthViewModel authVM) {
    if (authVM.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return authVM.currentUser == null 
        ? const LoginScreen()
        : const RoleBasedUI();
  }
}