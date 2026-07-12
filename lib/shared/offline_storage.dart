import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';

/// OfflineStorage — SafeWalk KT local cache manager
/// Wraps SharedPreferences with typed helpers for all offline data.
/// Used by home_map_page, alerts_page, and new_report_page.
class OfflineStorage {
  static const _keyHotspots       = 'cache_hotspots';
  static const _keyAlerts         = 'cache_alerts';
  static const _keyPendingReports = 'pending_reports';
  static const _keyLastSync       = 'last_sync_time';

  // ── HOTSPOTS ─────────────────────────────────────────────────────────────

  static Future<void> saveHotspots(List<dynamic> hotspots) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHotspots, jsonEncode(hotspots));
    await prefs.setString(_keyLastSync, DateTime.now().toIso8601String());
    dev.log('[Cache] Saved ${hotspots.length} hotspots to local cache');
  }

  static Future<List<dynamic>> loadHotspots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyHotspots);
    if (raw == null) return [];
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  // ── ALERTS ───────────────────────────────────────────────────────────────

  static Future<void> saveAlerts(List<dynamic> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAlerts, jsonEncode(alerts));
    dev.log('[Cache] Saved ${alerts.length} alerts to local cache');
  }

  static Future<List<dynamic>> loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyAlerts);
    if (raw == null) return [];
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  // ── PENDING REPORTS (submitted offline, waiting to sync) ─────────────────

  static Future<void> savePendingReport(Map<String, dynamic> report) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadPendingReports();
    existing.add(report);
    await prefs.setString(_keyPendingReports, jsonEncode(existing));
    dev.log('[Cache] Queued 1 pending report (total: ${existing.length})');
  }

  static Future<List<Map<String, dynamic>>> loadPendingReports() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPendingReports);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearPendingReports() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingReports);
    dev.log('[Cache] Cleared pending reports after sync');
  }

  static Future<int> pendingReportCount() async {
    final list = await loadPendingReports();
    return list.length;
  }

  // ── LAST SYNC TIME ────────────────────────────────────────────────────────

  static Future<String> getLastSyncLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastSync);
    if (raw == null) return 'Never synced';

    try {
      final dt = DateTime.parse(raw);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Unknown';
    }
  }

  // ── CLEAR ALL CACHE ───────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHotspots);
    await prefs.remove(_keyAlerts);
    await prefs.remove(_keyLastSync);
    dev.log('[Cache] All cache cleared');
  }

  // ── CACHE AGE CHECK ───────────────────────────────────────────────────────

  /// Returns true if cache is older than [maxAgeMinutes]
  static Future<bool> isCacheStale({int maxAgeMinutes = 60}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastSync);
    if (raw == null) return true;
    try {
      final dt = DateTime.parse(raw);
      return DateTime.now().difference(dt).inMinutes > maxAgeMinutes;
    } catch (_) {
      return true;
    }
  }
}