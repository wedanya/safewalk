import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/offline_storage.dart';
import 'alerts_state.dart';

export 'alerts_state.dart';

class AlertsCubit extends Cubit<AlertsState> {
  AlertsCubit() : super(AlertsInitial());

  final _db = Supabase.instance.client;

  Future<void> fetchAlerts({bool isOnline = true}) async {
    emit(AlertsLoading());

    if (!isOnline) {
      final cached = await OfflineStorage.loadHotspots();
      final label  = await OfflineStorage.getLastSyncLabel();
      emit(AlertsLoaded(
        List<Map<String, dynamic>>.from(cached),
        fromCache: true,
        lastUpdated: cached.isNotEmpty ? 'Cached $label' : 'No cache available',
      ));
      return;
    }

    try {
      final response = await _db
          .from('hotspots')
          .select()
          .eq('verified', true)
          .order('crime_count', ascending: false);

      final data = List<Map<String, dynamic>>.from(response as List);
      if (data.isNotEmpty) await OfflineStorage.saveHotspots(data);

      emit(AlertsLoaded(data, fromCache: false, lastUpdated: 'Just now'));
    } catch (e) {
      final cached = await OfflineStorage.loadHotspots();
      final label  = await OfflineStorage.getLastSyncLabel();
      emit(AlertsError(
        'Could not refresh alerts',
        cachedHotspots: List<Map<String, dynamic>>.from(cached),
        lastUpdated: cached.isNotEmpty ? 'Cached $label' : 'Could not refresh',
      ));
    }
  }
}