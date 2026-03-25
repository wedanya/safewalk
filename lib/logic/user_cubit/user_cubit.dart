import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_state.dart';
import '../../models/incident_model.dart';
import '../../shared/constants.dart';

class UserCubit extends Cubit<UserState> {
  UserCubit() : super(UserInitial());

  // 1. Fetch the Alerts for the AlertsPage (Screen 2)
  Future<void> fetchNearbyAlerts() async {
    emit(UserLoading());
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/incidents'));
      
      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        final alerts = data.map((json) => IncidentModel.fromJson(json)).toList();
        emit(UserLoaded(alerts));
      } else {
        emit(const UserError("Failed to sync with server"));
      }
    } catch (e) {
      emit(UserError(e.toString()));
    }
  }

  // 2. Submit a New Incident (Screen 3)
  Future<void> submitReport(IncidentModel report) async {
    emit(UserLoading());
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/report'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(report.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        emit(UserReportSuccess());
        // Refresh the list after successful report
        fetchNearbyAlerts(); 
      } else {
        emit(const UserError("Could not submit report."));
      }
    } catch (e) {
      emit(UserError("Connection Error: Check your Flask server."));
    }
  }
}