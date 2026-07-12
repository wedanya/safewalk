import 'dart:developer' as dev;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/offline_storage.dart';
import '../../shared/connectivity_service.dart';
import 'report_state.dart';

export 'report_state.dart';

class ReportCubit extends Cubit<ReportState> {
  ReportCubit() : super(ReportInitial());

  final _db = Supabase.instance.client;

  // ── Called once when NewReportPage opens ─────────────────────────────────
  Future<void> init() async {
    final isOnline = ConnectivityService().isOnline;

    // If online, try to sync any previously queued offline reports first
    int synced = 0;
    if (isOnline) {
      synced = await _syncPending();
    }

    final pending = await OfflineStorage.loadPendingReports();

    emit(ReportLocationReady(
      isOnline: isOnline,
      pendingCount: pending.length,
      lastSyncedCount: synced,
    ));

    await fetchLocation(isOnline: isOnline);
  }

  // ── Select incident type ──────────────────────────────────────────────────
  void selectType(String type) {
    final current = state is ReportLocationReady
        ? state as ReportLocationReady
        : ReportLocationReady();
    emit(current.copyWith(selectedType: type));
  }

  // ── Fetch GPS location ────────────────────────────────────────────────────
  Future<void> fetchLocation({required bool isOnline}) async {
    final current = state is ReportLocationReady
        ? state as ReportLocationReady
        : ReportLocationReady(isOnline: isOnline);

    emit(ReportFetchingLocation());

    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        emit(current.copyWith(
          locationLabel: 'Location permission denied',
          isOnline: isOnline,
        ));
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final label =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';

      emit(current.copyWith(
        lat: pos.latitude,
        lng: pos.longitude,
        locationLabel: label,
        isOnline: isOnline,
      ));
    } catch (e) {
      dev.log('[ReportCubit] fetchLocation error: $e');
      emit(current.copyWith(
        locationLabel: 'Could not get location',
        isOnline: isOnline,
      ));
    }
  }

  // ── Submit report ─────────────────────────────────────────────────────────
  Future<void> submitReport({required String details, String? imageUrl}) async {
    if (state is! ReportLocationReady) return;
    final locationState = state as ReportLocationReady;

    if (locationState.selectedType.isEmpty) {
      emit(ReportSubmitFailure('Please select a report type.'));
      return;
    }

    emit(ReportSubmitting(locationState));

    final report = {
      'type':       locationState.selectedType,
      'details':    details,
      'lat':        locationState.lat,
      'lng':        locationState.lng,
      'district':   locationState.district ?? 'Kuala Terengganu',
      'source':     'user_report',
      'verified':   false,
      'user_id':    _db.auth.currentUser?.id,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'image_url': imageUrl,
    };

    // Offline — queue the report locally
    if (!locationState.isOnline) {
      await OfflineStorage.savePendingReport(report);
      emit(ReportSubmitSuccess(savedOffline: true));
      return;
    }

    try {
      await _db.from('hotspots').insert(report);
      emit(ReportSubmitSuccess(savedOffline: false));
    } catch (e) {
      dev.log('[ReportCubit] submitReport error: $e');
      // Upload failed — save offline as fallback
      await OfflineStorage.savePendingReport(report);
      emit(ReportSubmitFailure(
        'Upload failed — saved offline. Will sync when reconnected.',
        savedOffline: true,
      ));
    }
  }

  // ── Sync queued offline reports when back online ──────────────────────────
  Future<void> syncPendingReports() async {
    final synced = await _syncPending();
    final remaining = await OfflineStorage.loadPendingReports();

    final current = state is ReportLocationReady
        ? state as ReportLocationReady
        : ReportLocationReady();
    emit(current.copyWith(
      pendingCount: remaining.length,
      lastSyncedCount: synced,
    ));
  }

  // ── Internal: upload all pending reports, clear queue on full success ─────
  Future<int> _syncPending() async {
    final pending = await OfflineStorage.loadPendingReports();
    if (pending.isEmpty) return 0;

    int successCount = 0;
    for (final r in pending) {
      try {
        await _db.from('hotspots').insert(r);
        successCount++;
      } catch (e) {
        dev.log('[ReportCubit] Failed to sync report: $e');
      }
    }

    // If all succeeded, clear the whole queue
    if (successCount == pending.length) {
      await OfflineStorage.clearPendingReports();
    }
    // If partial success, we can't remove individually (no removePendingReport),
    // so leave the queue intact — duplicates are prevented by Supabase's
    // unique constraint on (user_id, created_at) if you add one, otherwise
    // add a removePendingReport method to OfflineStorage for finer control.

    return successCount;
  }
}