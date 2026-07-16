import 'package:flutter/material.dart';
import 'admin/admin_main.dart';
// Note: You'll need an entry point for your user side, 
// usually a file that handles the BottomNavigationBar for user pages.
import 'user/map_page.dart'; 

class DevEntryPage extends StatelessWidget {
  const DevEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Dark professional dev theme
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.developer_mode, color: Colors.blueAccent, size: 60),
            const SizedBox(height: 20),
            const Text(
              "SAFEWALK DEV PORTAL",
              style: TextStyle(
                color: Colors.white, 
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 40),
            
            // ADMIN BUTTON
            _entryButton(
              context,
              label: "ADMIN",
              icon: Icons.admin_panel_settings,
              color: Colors.orangeAccent,
              destination: const AdminMain(),
            ),
            
            const SizedBox(height: 20),
            
            // USER BUTTON
            _entryButton(
              context,
              label: "CITIZEN",
              icon: Icons.person,
              color: Colors.blueAccent,
              destination: const MapPage(), // Or your main user navigation file
            ),
            
            const SizedBox(height: 40),
            const Text(
              "Switch roles easily during development",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryButton(BuildContext context, {
    required String label, 
    required IconData icon, 
    required Color color, 
    required Widget destination
  }) {
    return SizedBox(
      width: 280,
      height: 70,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 8,
        ),
        onPressed: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => destination)
        ),
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}