import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/admin_cubit/admin_logic.dart'; // Corrected import
import 'dashboard_page.dart';
import 'kmeans_page.dart';
import 'report_list_page.dart';

class AdminMain extends StatelessWidget {
  const AdminMain({super.key});

  @override
  Widget build(BuildContext context) {
    // We provide the Cubit here so all Admin pages can access it
    return BlocProvider(
      create: (context) => AdminCubit()..fetchPendingReports(),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        // !!! FIX HERE: Points to the actual Admin UI, not the DevEntryPage
        home: AdminBottomNav(), 
      ), // Change this from DevEntryPage to AdminBottomNav
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
  
  // Ensure these classes are imported correctly at the top
  final List<Widget> _pages = [
    const DashboardPage(), 
    const ReportListPage(), 
    const KMeansPage()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Statistics"),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: "Verify"),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: "K-Means"),
        ],
      ),
    );
  }
}