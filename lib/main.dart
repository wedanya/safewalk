import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// --- IMPORTANT: Ensure these match your actual folder names ---
import 'presentation/admin/dashboard_page.dart';
import 'presentation/admin/kmeans_page.dart';
import 'presentation/admin/report_list_page.dart';
import 'logic/admin_cubit/admin_logic.dart';
import 'presentation/dev_entry_page.dart';

void main() {
  runApp(const AdminMain());
}

class AdminMain extends StatelessWidget {
  const AdminMain({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // This initializes the brain of the Admin panel and fetches data immediately
      create: (context) => AdminCubit()..fetchPendingReports(),
      child: MaterialApp(
        title: 'SafeWalk Admin',
        debugShowCheckedModeBanner: false, // Removes the debug banner
        theme: ThemeData(
          useMaterial3: true,
          // FIX: This solves the "Failed assertion" red screen error
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.red,
            brightness: Brightness.light, 
          ),
          brightness: Brightness.light,
        ),
        home: const DevEntryPage(),
      ),
    );
  }
}

class AdminBottomNav extends StatefulWidget {
  const AdminBottomNav({super.key});

  @override
  State<AdminBottomNav> createState() => _AdminBottomNavState();
}

class _AdminBottomNavState extends State<AdminBottomNav> {
  int _currentIndex = 0;

  // The list of pages defined in your separate files
  final List<Widget> _pages = const [
    DashboardPage(),
    ReportListPage(),
    KMeansPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: "Stats",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined),
            activeIcon: Icon(Icons.fact_check),
            label: "Verify",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: "K-Means",
          ),
        ],
      ),
    );
  }
}