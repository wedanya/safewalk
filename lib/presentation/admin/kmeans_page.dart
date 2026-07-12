import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/admin_cubit/admin_logic.dart';
import '../../features/admin/cluster_detail_page.dart';

class KMeansPage extends StatelessWidget {
  const KMeansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Algorithm Management"),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: BlocConsumer<AdminCubit, AdminState>(
        // Show snackbar for success message or errors
        listenWhen: (_, curr) =>
            curr is AdminError ||
            (curr is AdminLoaded && curr.successMessage != null),
        listener: (context, state) {
          if (state is AdminError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ));
          } else if (state is AdminLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ));
          }
        },
        builder: (context, state) {
          final isLoading = state is AdminLoading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Icon hero
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.radar, size: 72, color: Colors.redAccent),
                ),
                const SizedBox(height: 24),
                const Text("Update Red Zone Clusters",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  "This triggers the Scikit-Learn K-Means script to recalculate "
                  "hotspot clusters for Kuala Terengganu based on the latest "
                  "verified incident data.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], height: 1.5),
                ),
                const SizedBox(height: 32),

                // Stats row — shows current cluster data from state
                if (state is AdminLoaded) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statChip("Pending", state.pendingCount.toString(),
                          Colors.orange),
                      _statChip("Verified", state.verifiedCount.toString(),
                          Colors.green),
                      _statChip("Dismissed", state.dismissedCount.toString(),
                          Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],

                // Run button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: isLoading
                        ? null
                        : () =>
                            context.read<AdminCubit>().runKMeansClustering(),
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow_rounded,
                            color: Colors.white),
                    label: Text(
                      isLoading ? "Running Algorithm..." : "Run K-Means Now",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ),
                if (state is AdminLoaded && state.successMessage != null) ...[
  const SizedBox(height: 20),
  OutlinedButton.icon(
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClusterDetailPage()),
    ),
    icon: const Icon(Icons.map_outlined, color: Colors.redAccent),
    label: const Text('View Cluster Map',
        style: TextStyle(color: Colors.redAccent)),
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: Colors.redAccent),
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
],

                const SizedBox(height: 16),
                Text(
                  "⚠️  This operation may take a few seconds.",
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}