import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'my_reports_state.dart';

export 'my_reports_state.dart'; // so pages only need one import

class MyReportsCubit extends Cubit<MyReportsState> {
  MyReportsCubit() : super(MyReportsInitial());

  final _db = Supabase.instance.client;

  Future<void> fetchMyReports() async {
    emit(MyReportsLoading());
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) { emit(MyReportsError('Not logged in')); return; }
      final data = await _db
          .from('hotspots')
          .select()
          .eq('user_id', uid)
          .eq('source', 'user_report')
          .order('created_at', ascending: false);
      emit(MyReportsLoaded(List<Map<String, dynamic>>.from(data)));
    } catch (e) {
      emit(MyReportsError('Failed to load: $e'));
    }
  }

  Future<void> deleteReport(String id) async {
    try {
      await _db.from('hotspots').delete().eq('id', id);
      await fetchMyReports(); // refresh
    } catch (e) {
      emit(MyReportsError('Could not delete: $e'));
    }
  }
}