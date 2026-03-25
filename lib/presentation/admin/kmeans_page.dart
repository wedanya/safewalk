import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/admin_cubit/admin_logic.dart';

class KMeansPage extends StatelessWidget {
  const KMeansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Algorithm Management")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.radar, size: 100, color: Colors.redAccent),
            SizedBox(height: 20),
            Text("Update Red Zone Clusters", style: TextStyle(fontSize: 18)),
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Text("This will trigger the Scikit-Learn script to recalculate coordinates for Kuala Terengganu.", textAlign: TextAlign.center),
            ),
            BlocBuilder<AdminCubit, AdminState>(
              builder: (context, state) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: state is AdminLoading ? null : () => context.read<AdminCubit>().runKMeansClustering(),
                  child: state is AdminLoading ? CircularProgressIndicator() : Text("RUN K-MEANS NOW"),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}