import 'package:flutter/material.dart';
import '../auth/login_page.dart'; // Adjust path if needed
import '../admin/admin_main.dart'; // Adjust path if needed

class SelectionPage extends StatelessWidget {
  const SelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3B71FE), Colors.white],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "WELCOME TO\nSAFEWALK KT",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 50),
                
                // CITIZEN BUTTON
                _buildRoleButton(
                  context,
                  title: "CITIZEN",
                  icon: Icons.person,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())),
                ),
                
                const SizedBox(height: 30),
                
                // ADMIN BUTTON
                _buildRoleButton(
                  context,
                  title: "ADMIN",
                  icon: Icons.admin_panel_settings,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminMain())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Icon(icon, size: 60, color: const Color(0xFF3B71FE)),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3B71FE),
            ),
          ),
        ],
      ),
    );
  }
}