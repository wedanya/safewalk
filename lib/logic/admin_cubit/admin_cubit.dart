import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_state.dart';

class AdminCubit extends Cubit<AdminState> {
  AdminCubit() : super(AdminInitial());

  final _db = Supabase.instance.client;

  // ── Fetch ALL reports from hotspots table ─────────────────────────────────
  Future<void> fetchPendingReports() async {
    emit(AdminLoading());
    try {
      final data = await _db
          .from('hotspots')
          .select()
          .order('created_at', ascending: false);

      final reports = List<Map<String, dynamic>>.from(data).map((r) {
        // Normalise status field — Supabase uses 'verified' boolean
        // map to a string status so report_list_page filters work
        final bool? verified = r['verified'] as bool?;
        final bool? dismissed = r['dismissed'] as bool?;
        String status;
        if (dismissed == true) {
          status = 'dismissed';
        } else if (verified == true) {
          status = 'verified';
        } else {
          status = 'pending';
        }
        return {...r, 'status': status};
      }).toList();

      emit(AdminLoaded(reports));
    } catch (e) {
      emit(AdminError("Failed to load reports: $e"));
    }
  }

  // ── Verify a report ───────────────────────────────────────────────────────
  Future<void> verifyIncident(String reportId) async {
    _updateLocalStatus(reportId, 'verified');
    try {
      await _db
          .from('hotspots')
          .update({'verified': true, 'dismissed': false})
          .eq('id', reportId);

      // After verifying, prompt admin to re-run K-Means
      if (state is AdminLoaded) {
        emit(AdminLoaded(
          (state as AdminLoaded).reports,
          successMessage: 'kMeansPrompt', // special key — UI checks for this
        ));
      }
    } catch (e) {
      _updateLocalStatus(reportId, 'pending');
      emit(AdminError("Could not verify report: \$e"));
    }
  }

  // ── Dismiss a report ──────────────────────────────────────────────────────
  Future<void> dismissIncident(String reportId, {String? reason}) async {
    _updateLocalStatus(reportId, 'dismissed', reason: reason);

    try {
      await _db
          .from('hotspots')
          .update({
            'verified':      false,
            'dismissed':     true,
            'dismiss_reason': reason ?? '',
          })
          .eq('id', reportId);
    } catch (e) {
      _updateLocalStatus(reportId, 'pending');
      emit(AdminError("Could not dismiss report: $e"));
    }
  }

  // ── K-Means clustering ────────────────────────────────────────────────────
  // Runs clustering directly in Dart on verified hotspot coordinates.
  Future<void> runKMeansClustering() async {
    final currentReports = (state is AdminLoaded)
        ? List<Map<String, dynamic>>.from((state as AdminLoaded).reports)
        : <Map<String, dynamic>>[];

    emit(AdminLoading());
    try {
      // Fetch all verified hotspots
      final data = await _db
          .from('hotspots')
          .select('id, lat, lng')
          .eq('verified', true);

      final points = List<Map<String, dynamic>>.from(data);
      if (points.length < 3) {
        emit(AdminLoaded(currentReports,
            successMessage: "Not enough verified reports to cluster (need at least 3)."));
        return;
      }

      final k = points.length < 6 ? 2 : 3;
      final clusters = _kMeans(points, k);

      // Write cluster assignment back to each hotspot row
      for (int i = 0; i < clusters.length; i++) {
        for (final point in clusters[i]) {
          await _db
              .from('hotspots')
              .update({'cluster': i})
              .eq('id', point['id']);
        }
      }

      await fetchPendingReports();

      if (state is AdminLoaded) {
        emit(AdminLoaded(
          (state as AdminLoaded).reports,
          successMessage: "K-Means complete! $k clusters assigned to ${points.length} hotspots.",
        ));
      }
    } catch (e) {
      emit(AdminLoaded(currentReports, successMessage: null));
      emit(AdminError("Clustering failed: $e"));
    }
  }

  // ── Pure Dart K-Means implementation ──────────────────────────────────────
  List<List<Map<String, dynamic>>> _kMeans(
      List<Map<String, dynamic>> points, int k,
      {int maxIter = 100}) {
    // Initialise centroids from first k points
    List<double> cLat = List.generate(k, (i) => (points[i]['lat'] as num).toDouble());
    List<double> cLng = List.generate(k, (i) => (points[i]['lng'] as num).toDouble());
    List<int> assignments = List.filled(points.length, 0);

    for (int iter = 0; iter < maxIter; iter++) {
      bool changed = false;

      // Assignment step
      for (int p = 0; p < points.length; p++) {
        final lat = (points[p]['lat'] as num).toDouble();
        final lng = (points[p]['lng'] as num).toDouble();
        int best = 0;
        double bestDist = double.infinity;
        for (int c = 0; c < k; c++) {
          final d = _dist(lat, lng, cLat[c], cLng[c]);
          if (d < bestDist) { bestDist = d; best = c; }
        }
        if (assignments[p] != best) { assignments[p] = best; changed = true; }
      }

      if (!changed) break;

      // Update step
      for (int c = 0; c < k; c++) {
        final members = <int>[];
        for (int p = 0; p < points.length; p++) {
          if (assignments[p] == c) members.add(p);
        }
        if (members.isEmpty) continue;
        cLat[c] = members.map((p) => (points[p]['lat'] as num).toDouble()).reduce((a, b) => a + b) / members.length;
        cLng[c] = members.map((p) => (points[p]['lng'] as num).toDouble()).reduce((a, b) => a + b) / members.length;
      }
    }

    // Build result
    final result = List.generate(k, (_) => <Map<String, dynamic>>[]);
    for (int p = 0; p < points.length; p++) {
      result[assignments[p]].add(points[p]);
    }
    return result;
  }

  double _dist(double lat1, double lng1, double lat2, double lng2) {
    final dlat = lat1 - lat2;
    final dlng = lng1 - lng2;
    return dlat * dlat + dlng * dlng; // squared Euclidean — sufficient for small areas
  }

  // ── Internal: mutate single report in loaded list ─────────────────────────
  void _updateLocalStatus(String reportId, String newStatus, {String? reason}) {
    if (state is! AdminLoaded) return;
    final updated = List<Map<String, dynamic>>.from(
            (state as AdminLoaded).reports)
        .map((r) {
          if (r['id']?.toString() == reportId) {
            return {
              ...r,
              'status':        newStatus,
              'verified':      newStatus == 'verified',
              'dismissed':     newStatus == 'dismissed',
              'dismiss_reason': reason,
            };
          }
          return r;
        })
        .toList();
    emit(AdminLoaded(updated));
  }
}