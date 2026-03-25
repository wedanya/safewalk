import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'admin_state.dart';

class AdminCubit extends Cubit<AdminState> {
  // Replace with your actual Flask server IP (use 10.0.2.2 for Android Emulator)
  final String baseUrl = "http://169.254.31.167:5000"; 

  AdminCubit() : super(AdminInitial());

  // --- FETCH PENDING REPORTS ---
  Future<void> fetchPendingReports() async {
    emit(AdminLoading());
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/reports/pending'));
      
      if (response.statusCode == 200) {
        List<Map<String, dynamic>> reports = List<Map<String, dynamic>>.from(json.decode(response.body));
        emit(AdminLoaded(reports));
      } else {
        emit(AdminError("Failed to load reports from server."));
      }
    } catch (e) {
      emit(AdminError("Connection Error: Check if Flask server is running."));
    }
  }

  // --- VERIFY AN INCIDENT ---
  Future<void> verifyIncident(String reportId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/verify'),
        body: json.encode({"id": reportId}),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        // Refresh the list after verification
        fetchPendingReports(); 
      } else {
        emit(AdminError("Could not verify report."));
      }
    } catch (e) {
      emit(AdminError("Verification failed due to network error."));
    }
  }

  // --- TRIGGER K-MEANS ALGORITHM ---
  Future<void> runKMeansClustering() async {
    emit(AdminLoading());
    try {
      // This calls the Python script that runs Scikit-Learn KMeans
      final response = await http.post(Uri.parse('$baseUrl/admin/run-kmeans'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Refresh and show success
        await fetchPendingReports(); 
        emit(AdminLoaded(
          (state as AdminLoaded).reports, 
          successMessage: "K-Means recalculated! ${data['clusters']} clusters updated."
        ));
      } else {
        emit(AdminError("Algorithm execution failed."));
      }
    } catch (e) {
      emit(AdminError("Failed to trigger backend clustering."));
    }
  }
}