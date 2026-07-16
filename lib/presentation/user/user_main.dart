import 'package:flutter/material.dart';
import 'map_page.dart';
import 'alerts_page.dart';
import 'new_report_page.dart';
import 'my_reports_page.dart';
import 'profile_page.dart';
import '../../shared/sos_service.dart';
import '../../shared/sos_overlay.dart';

class UserMain extends StatefulWidget {
  const UserMain({super.key});

  @override
  State<UserMain> createState() => _UserMainState();
}

class _UserMainState extends State<UserMain> with WidgetsBindingObserver {
  int _currentIndex = 0;

  // Alerts (0) first, Map (1) second
  List<Widget> get _pages => [
    const AlertsPage(),       // index 0 — first tab
    const MapPage(),      // index 1 — map
    NewReportPage(            // index 2 — centre +
      onSubmitSuccess: () => setState(() => _currentIndex = 0),
    ),
    const MyReportsPage(),    // index 3
    const ProfilePage(),      // index 4
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SosService.instance.start(() {
      if (mounted) SosOverlay.show(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SosService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!SosService.instance.isRunning) {
        SosService.instance.start(() {
          if (mounted) SosOverlay.show(context);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      // SafeArea fits content to phone screen, bottom:false lets dock float
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
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
          // Alerts first
          _buildNavItem(Icons.notifications_none, Icons.notifications, 0),
          // Map second
          _buildNavItem(Icons.map_outlined, Icons.map, 1),
          // Centre + button
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
                color: const Color(0xFF3B71FE).withValues(alpha: 0.1),
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