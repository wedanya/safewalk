import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 40, backgroundColor: Colors.blue, child: Icon(Icons.security, size: 40, color: Colors.white)),
            const SizedBox(height: 20),
            const Text("SafeWalk", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text("Your safety starts here.", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 40),
            TextField(decoration: InputDecoration(labelText: "Email or Phone Number", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 20),
            TextField(obscureText: true, decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600]), child: const Text("Login", style: TextStyle(color: Colors.white))),
            ),
          ],
        ),
      ),
    );
  }
}