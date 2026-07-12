import 'package:flutter/material.dart';
import 'auth/login_page.dart'; // Ensure this matches your login file name

class SelectionPage extends StatelessWidget {
  const SelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your SafeWalk Logo
            const Icon(Icons.shield_outlined, size: 100, color: Color(0xFF3B71FE)),
            const SizedBox(height: 20),
            const Text(
              "SAFEWALK KT",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF22355F)),
            ),
            const SizedBox(height: 10),
            const Text(
              "Navigate your city with confidence and AI-powered safety.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 50),
            
            // Login Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B71FE),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Login to My Account", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Temporary Guest Access or Info Button
            TextButton(
              onPressed: () {
                // You can add a "Continue as Guest" or "About the Project" here
              },
              child: const Text("Need an account? Contact Admin", style: TextStyle(color: Color(0xFF3B71FE))),
            ),
          ],
        ),
      ),
    );
  }
}