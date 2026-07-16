import 'dart:math';
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

  // ── K-Means clustering config ─────────────────────────────────────────────
  // Tune these to change how "walkable" a zone is and how many reports it
  // takes to flag a cluster as Caution/Danger.
  static const int _minPointsToCluster = 3;   // floor before clustering runs at all
  static const int _minClusters        = 1;   // start as small as possible — growth loop below
                                                // only increases k when a cluster is too wide,
                                                // so starting low keeps well-separated groups intact
  static const int _maxClusters        = 40;  // raised from 20 — a smaller radius needs
                                                // more clusters to cover the same district
  static const int _kMeansRestarts     = 5;   // random-seed attempts per k — keep the tightest fit

  static const double _maxClusterRadiusMetres = 250; // ~3-4 min walk — street-level, tuned for
                                                        // single-district scope (Kuala Terengganu)

  // Risk is based on the SUM of crime_count across all reports in a zone —
  // not just how many report rows fall inside it. A single report can carry
  // a large historical case count (e.g. seeded district stats), so counting
  // rows alone would under-flag zones that only have one high-count report.
  static const int _dangerCaseThreshold  = 300; // zone needs >= this many total cases to be Danger
  static const int _cautionCaseThreshold = 100; // >= this many (but < danger) to be Caution
  // below _cautionCaseThreshold → Safe

  // ── K-Means clustering ────────────────────────────────────────────────────
  // Runs clustering directly in Dart on verified hotspot coordinates, then
  // labels each cluster Danger/Caution/Safe by how many reports fall inside
  // it — so risk reflects the actual walking-distance zone around a report,
  // not just a whole district.
  Future<void> runKMeansClustering() async {
    final currentReports = (state is AdminLoaded)
        ? List<Map<String, dynamic>>.from((state as AdminLoaded).reports)
        : <Map<String, dynamic>>[];

    emit(AdminLoading());
    try {
      // Fetch all verified hotspots
      final data = await _db
          .from('hotspots')
          .select('id, lat, lng, crime_count')
          .eq('verified', true);

      final points = List<Map<String, dynamic>>.from(data);
      if (points.length < _minPointsToCluster) {
        emit(AdminLoaded(currentReports,
            successMessage:
                "Not enough verified reports to cluster (need at least $_minPointsToCluster)."));
        return;
      }

      // Start as small as possible (k=1) and only grow when a cluster's
      // real-world spread exceeds the walking-distance target. Starting low
      // — combined with k-means++ seeding and multiple restarts in
      // _bestKMeans — means a tight, well-separated group of reports stays
      // as one zone regardless of how many unrelated reports exist
      // elsewhere in the table, instead of being fragmented by an
      // oversized k guessed from the total row count.
      int k = _minClusters;
      List<List<Map<String, dynamic>>> clusters = _bestKMeans(points, k);

      while (k < _maxClusters && k < points.length) {
        final tooWide = clusters.any((members) =>
            members.isNotEmpty &&
            _clusterRadiusMetres(members) > _maxClusterRadiusMetres);
        if (!tooWide) break;
        k++;
        clusters = _bestKMeans(points, k);
      }

      // Assign a risk label per cluster based on its TOTAL case count,
      // then write both cluster index and risk back to each member row.
      int dangerZones = 0, cautionZones = 0, safeZones = 0;
      for (int i = 0; i < clusters.length; i++) {
        final members = clusters[i];
        if (members.isEmpty) continue;

        final totalCases = members.fold<int>(
            0, (sum, p) => sum + ((p['crime_count'] as num?)?.toInt() ?? 0));
        final risk = _riskForCaseCount(totalCases);
        if (risk == 'Danger') {
          dangerZones++;
        } else if (risk == 'Caution') {
          cautionZones++;
        } else {
          safeZones++;
        }

        for (final point in members) {
          await _db
              .from('hotspots')
              .update({'cluster': i, 'risk': risk})
              .eq('id', point['id']);
        }
      }

      await fetchPendingReports();

      if (state is AdminLoaded) {
        emit(AdminLoaded(
          (state as AdminLoaded).reports,
          successMessage:
              "K-Means complete! $k walkable zones (≤${_maxClusterRadiusMetres.toInt()}m) "
              "from ${points.length} reports — "
              "$dangerZones Danger, $cautionZones Caution, $safeZones Safe.",
        ));
      }
    } catch (e) {
      emit(AdminLoaded(currentReports, successMessage: null));
      emit(AdminError("Clustering failed: $e"));
    }
  }

  // ── Risk label from total case count within a cluster ─────────────────────
  String _riskForCaseCount(int totalCases) {
    if (totalCases >= _dangerCaseThreshold) return 'Danger';
    if (totalCases >= _cautionCaseThreshold) return 'Caution';
    return 'Safe';
  }

  // ── Cluster spread check — real-world radius, not raw lat/lng distance ────
  // Centroid here is just the mean position of the cluster's own members —
  // same thing K-Means converges to internally — recomputed so we can
  // measure the result in actual metres.
  double _clusterRadiusMetres(List<Map<String, dynamic>> members) {
    final avgLat = members.map((p) => (p['lat'] as num).toDouble())
            .reduce((a, b) => a + b) / members.length;
    final avgLng = members.map((p) => (p['lng'] as num).toDouble())
            .reduce((a, b) => a + b) / members.length;

    double maxDist = 0;
    for (final p in members) {
      final d = _haversineMetres(
          avgLat, avgLng,
          (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
      if (d > maxDist) maxDist = d;
    }
    return maxDist;
  }

  // Great-circle distance in metres between two lat/lng points.
  double _haversineMetres(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusMetres = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMetres * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);

  // ── K-Means with restarts — runs _kMeans several times with different
  // random k-means++ seeds and keeps the tightest-fitting result (lowest
  // inertia). A single run can land in a mediocre local optimum purely by
  // chance of where its centroids started; running a handful of attempts
  // and keeping the best is standard practice (same idea as scikit-learn's
  // n_init) and makes the result far less sensitive to seed luck.
  List<List<Map<String, dynamic>>> _bestKMeans(
      List<Map<String, dynamic>> points, int k) {
    List<List<Map<String, dynamic>>>? best;
    double bestInertia = double.infinity;
    for (int attempt = 0; attempt < _kMeansRestarts; attempt++) {
      final clusters = _kMeans(points, k);
      final inertia = _inertia(clusters);
      if (inertia < bestInertia) {
        bestInertia = inertia;
        best = clusters;
      }
    }
    return best!;
  }

  // Total squared distance from each point to its own cluster's centroid —
  // lower means a tighter, better-converged clustering.
  double _inertia(List<List<Map<String, dynamic>>> clusters) {
    double total = 0;
    for (final members in clusters) {
      if (members.isEmpty) continue;
      final avgLat = members.map((p) => (p['lat'] as num).toDouble())
              .reduce((a, b) => a + b) / members.length;
      final avgLng = members.map((p) => (p['lng'] as num).toDouble())
              .reduce((a, b) => a + b) / members.length;
      for (final p in members) {
        total += _dist(avgLat, avgLng,
            (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
      }
    }
    return total;
  }

  // ── Pure Dart K-Means implementation ──────────────────────────────────────
  List<List<Map<String, dynamic>>> _kMeans(
      List<Map<String, dynamic>> points, int k,
      {int maxIter = 100}) {
    final n = points.length;
    final rand = Random();

    // k-means++ seeding — pick the first centroid at random, then each next
    // centroid with probability proportional to its squared distance from
    // the nearest centroid already chosen. This spreads centroids out
    // toward real density peaks instead of clumping near whatever rows
    // happened to load first from the database (the old behaviour), which
    // is what let a tight, well-separated batch of reports get arbitrarily
    // fragmented once k grew for unrelated reasons.
    final List<double> cLat = [];
    final List<double> cLng = [];
    final firstIdx = rand.nextInt(n);
    cLat.add((points[firstIdx]['lat'] as num).toDouble());
    cLng.add((points[firstIdx]['lng'] as num).toDouble());

    while (cLat.length < k) {
      final distances = List.generate(n, (p) {
        final lat = (points[p]['lat'] as num).toDouble();
        final lng = (points[p]['lng'] as num).toDouble();
        double minD = double.infinity;
        for (int c = 0; c < cLat.length; c++) {
          final d = _dist(lat, lng, cLat[c], cLng[c]);
          if (d < minD) minD = d;
        }
        return minD;
      });
      final totalD = distances.fold<double>(0, (a, b) => a + b);
      if (totalD == 0) {
        // All remaining points coincide with an existing centroid — just
        // pick any point so we still reach k centroids.
        final idx = rand.nextInt(n);
        cLat.add((points[idx]['lat'] as num).toDouble());
        cLng.add((points[idx]['lng'] as num).toDouble());
        continue;
      }
      double r = rand.nextDouble() * totalD;
      int chosen = 0;
      for (int p = 0; p < n; p++) {
        r -= distances[p];
        if (r <= 0) { chosen = p; break; }
      }
      cLat.add((points[chosen]['lat'] as num).toDouble());
      cLng.add((points[chosen]['lng'] as num).toDouble());
    }

    List<int> assignments = List.filled(n, 0);

    for (int iter = 0; iter < maxIter; iter++) {
      bool changed = false;

      // Assignment step
      for (int p = 0; p < n; p++) {
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
        for (int p = 0; p < n; p++) {
          if (assignments[p] == c) members.add(p);
        }
        if (members.isEmpty) continue;
        cLat[c] = members.map((p) => (points[p]['lat'] as num).toDouble()).reduce((a, b) => a + b) / members.length;
        cLng[c] = members.map((p) => (points[p]['lng'] as num).toDouble()).reduce((a, b) => a + b) / members.length;
      }
    }

    // Build result
    final result = List.generate(k, (_) => <Map<String, dynamic>>[]);
    for (int p = 0; p < n; p++) {
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