import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/admin_cubit/admin_cubit.dart';
import '../../logic/admin_cubit/admin_state.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text("System Overview",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        // Inside AppBar actions
actions: [
  BlocBuilder<AdminCubit, AdminState>(
    builder: (context, state) {
      if (state is AdminLoading) { // Check if your Cubit state is loading
        return const Center(
          child: Padding(
            padding: EdgeInsets.only(right: 15),
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
            ),
          ),
        );
      }
      return IconButton(
        icon: const Icon(Icons.refresh, color: Colors.blue),
        onPressed: () => context.read<AdminCubit>().fetchPendingReports(),
      );
    },
  )
],
      ),
      // --- WRAP BODY WITH REFRESH INDICATOR ---
      body: RefreshIndicator(
        onRefresh: () async {
          // This allows "Pull to Refresh" gesture
          await context.read<AdminCubit>().fetchPendingReports();
        },
        child: BlocBuilder<AdminCubit, AdminState>(
          builder: (context, state) {
            int pendingCount = (state is AdminLoaded) ? state.reports.length : 0;

            return SingleChildScrollView(
              // Physics ensures pull-to-refresh works even if content is small
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Quick Statistics",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  
                  // Top Row: Big Primary Metric
                  _mainStatCard("Total Pending", pendingCount.toString(),
                      Icons.hourglass_empty, Colors.orange),
                  
                  const SizedBox(height: 20),
                  
                  // Grid for secondary stats
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.2,
                    children: [
                      _miniStatCard("Verified", "128", Icons.check_circle, Colors.green),
                      _miniStatCard("Red Zones", "5", Icons.location_on, Colors.red),
                      _miniStatCard("Active Users", "1.2k", Icons.people, Colors.blue),
                      _miniStatCard("Accuracy", "94%", Icons.auto_graph, Colors.purple),
                    ],
                  ),
                  
                  const SizedBox(height: 25),
                  const Text("System Health",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  
                  // Backend Status Card
                  _buildBackendStatusCard(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackendStatusCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        // ignore: deprecated_member_use
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.dns, color: Colors.green),
          const SizedBox(width: 15),
          const Expanded(
            child: Text("Flask Backend Server",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text("ONLINE",
                style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // Large Card for the most important number
  Widget _mainStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          // ignore: deprecated_member_use
          Icon(icon, color: Colors.white.withOpacity(0.5), size: 50),
        ],
      ),
    );
  }

  // Mini Cards for the Grid
  Widget _miniStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}