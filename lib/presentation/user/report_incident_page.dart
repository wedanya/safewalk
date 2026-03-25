import 'package:flutter/material.dart';

class ReportIncidentPage extends StatelessWidget {
  const ReportIncidentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Report Incident"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("CURRENT LOCATION", style: TextStyle(fontWeight: FontWeight.bold)),
            Container(height: 150, margin: const EdgeInsets.symmetric(vertical: 10), color: Colors.grey[200], child: const Center(child: Icon(Icons.map))),
            const Text("Select Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, childAspectRatio: 1.5,
              crossAxisSpacing: 10, mainAxisSpacing: 10,
              children: [
                _categoryCard("Suspicious Activity", Icons.visibility, Colors.blue),
                _categoryCard("Infrastructure", Icons.build, Colors.black),
                _categoryCard("Accident", Icons.car_crash, Colors.black),
                _categoryCard("Theft", Icons.warning, Colors.black),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.send),
                label: const Text("Submit Incident Report"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _categoryCard(String label, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(15)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, color: color), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold))],
      ),
    );
  }
}