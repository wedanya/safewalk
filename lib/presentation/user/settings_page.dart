import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
            child: CircleAvatar(radius: 50, backgroundImage: NetworkImage('https://via.placeholder.com/150')),
          ),
          const SizedBox(height: 10),
          const Center(child: Text("Ahmad Zaki", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          const SizedBox(height: 30),
          const Text("ACCOUNT CONFIGURATION", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ListTile(leading: const Icon(Icons.person_outline), title: const Text("Profile Settings"), trailing: const Icon(Icons.chevron_right)),
          const Divider(),
          const Text("NOTIFICATIONS & SAFETY", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          SwitchListTile(title: const Text("Risk Level Alerts"), value: true, onChanged: (v) {}),
          const SizedBox(height: 40),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text("Logout", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }
}