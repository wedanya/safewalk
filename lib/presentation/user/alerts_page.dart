import 'package:flutter/material.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Safety Alerts", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.black), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("RECENT INCIDENTS", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _alertCard("Theft Reported", "0.5km away • 20 mins ago", "Suspicious activity reported near...", Colors.red),
          _alertCard("Traffic Incident", "300m away • 5 mins ago", "Major congestion at roundabout...", Colors.orange),
          _alertCard("Street Light Outage", "1.2km away • 12 mins ago", "Dark area reported near Kuala...", Colors.yellow[700]!),
        ],
      ),
    );
  }

  Widget _alertCard(String title, String subtitle, String desc, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("$subtitle\n$desc"),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}