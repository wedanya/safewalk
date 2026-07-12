import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/admin_cubit/admin_logic.dart';

class VerificationPage extends StatelessWidget {
  const VerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Verify Incidents")),
      body: BlocBuilder<AdminCubit, AdminState>(
        builder: (context, state) {
          if (state is AdminLoading) return Center(child: CircularProgressIndicator());
          if (state is AdminLoaded) {
            return ListView.builder(
              itemCount: state.reports.length,
              itemBuilder: (context, index) {
                final report = state.reports[index];
                return Card(
                  child: ListTile(
                    title: Text(report['type']),
                    subtitle: Text(report['location']),
                    trailing: IconButton(
                      icon: Icon(Icons.check, color: Colors.green),
                      onPressed: () => context.read<AdminCubit>().verifyIncident(report['id']),
                    ),
                  ),
                );
              },
            );
          }
          return Center(child: Text("No data found."));
        },
      ),
    );
  }
}