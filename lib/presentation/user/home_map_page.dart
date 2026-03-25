import 'package:flutter/material.dart';

class HomeMapPage extends StatelessWidget {
  const HomeMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    // REMOVED Scaffold and AppBar from here
    return Stack(
      children: [
        // Placeholder for Google Map
        Container(
          color: Colors.blue[50], 
          child: const Center(child: Text("Map Integration Here"))
        ),
        
        // Search Bar & Risk Card
        Positioned(
          top: 100, 
          left: 20, 
          right: 20,
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: "Search safe routes...",
                  prefixIcon: const Icon(Icons.search),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15), 
                    borderSide: BorderSide.none
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _buildRiskCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRiskCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.orange[100]!)
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("CURRENT ZONE", style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text("You are in a Low Risk Zone", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("KT Waterfront Area • Updated now", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.orange[300], size: 40),
        ],
      ),
    );
  }
}