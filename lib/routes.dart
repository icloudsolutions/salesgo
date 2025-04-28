import 'package:salesgo/views/admin/reports_screen.dart';

import 'views/admin/admin_home_screen.dart';
import 'views/agent/agent_home_screen.dart';
import 'views/agent/sales_history_screen.dart';
import 'views/agent/stock_screen.dart';
import 'views/admin/users_management.dart';

final appRoutes = {
  '/history': (context) => const HistoryScreen(),
  '/stock': (context) => const StockScreen(),
  '/users': (context) => const UsersScreen(),
  '/admin': (context) => const AdminHomeScreen(),
  '/agent': (context) => const AgentHomeScreen(),
  '/reports': (context) => const ReportsScreen(),

};