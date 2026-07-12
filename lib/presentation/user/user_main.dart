import 'package:flutter/material.dart';
import 'home_map_page.dart';
import 'alerts_page.dart';
import 'new_report_page.dart';
import 'my_reports_page.dart';
import 'profile_page.dart';

class UserMain extends StatefulWidget {
  const UserMain({super.key});

  @override
  State<UserMain> createState() => _UserMainState();
}

class _UserMainState extends State<UserMain> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeMapPage(),      // index 0
    const AlertsPage(),       // index 1
    const NewReportPage(),    // index 2  (centre + button)
    const MyReportsPage(),    // index 3
    const ProfilePage(),      // index 4
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildFloatingDock(),
    );
  }

  Widget _buildFloatingDock() {
    return Container(
      height: 80,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.map_outlined, Icons.map, 0),
          _buildNavItem(Icons.notifications_none, Icons.notifications, 1),
          // Centre + button (new_report_page, index 2)
          GestureDetector(
            onTap: () => setState(() => _currentIndex = 2),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                color: Color(0xFF3B71FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          ),
          _buildNavItem(Icons.article_outlined, Icons.article, 3),
          _buildNavItem(Icons.person_outline, Icons.person, 4),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData outlineIcon, IconData filledIcon, int index) {
    final bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: isActive
            ? BoxDecoration(
                // ignore: deprecated_member_use
                color: const Color(0xFF3B71FE).withOpacity(0.1),
                shape: BoxShape.circle,
              )
            : null,
        child: Icon(
          isActive ? filledIcon : outlineIcon,
          color: isActive ? const Color(0xFF3B71FE) : const Color(0xFF7B8BB2),
          size: 28,
        ),
      ),
    );
  }
}