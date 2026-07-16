import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/connectivity_service.dart';
import '../../shared/offline_storage.dart';
import '../../shared/offline_banner.dart';
import 'alert_detail_page.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});
  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  List<dynamic> _allHotspots = [];
  List<Map<String, dynamic>> _allGroups = [];
  List<Map<String, dynamic>> _filtered  = [];
  bool   _isLoading    = true;
  String _lastUpdated  = 'Fetching...';
  bool   _isOnline     = true;
  bool   _fromCache    = false;
  String _activeFilter = 'All';
  String _searchQuery  = '';

  final TextEditingController _searchCtrl = TextEditingController();
  StreamSubscription<bool>?    _connectSub;
  RealtimeChannel?             _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService().isOnline;
    _connectSub = ConnectivityService().onChanged.listen((online) {
      if (mounted) { setState(() => _isOnline = online); if (online) _fetchAlerts(); }
    });
    _fetchAlerts();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _connectSub?.cancel();
    _realtimeChannel?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Realtime sync with database ───────────────────────────────────────────
  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('alerts:hotspots')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'hotspots',
          callback: (_) => _fetchAlerts(),
        )
        .subscribe();
  }

  // ── Fetch — same source as map ─────────────────────────────────────────────
  Future<void> _fetchAlerts() async {
    setState(() => _isLoading = true);
    if (!_isOnline) {
      final cached = await OfflineStorage.loadHotspots();
      final label  = await OfflineStorage.getLastSyncLabel();
      if (mounted) {
        setState(() {
          _allHotspots = cached;
          _lastUpdated = cached.isNotEmpty ? 'Cached $label' : 'No cache available';
          _fromCache   = true;
          _applyFilter();
          _isLoading   = false;
        });
      }
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('hotspots')
          .select()
          .eq('verified', true)
          .order('crime_count', ascending: false);
      final data = response as List<dynamic>;
      if (data.isNotEmpty) await OfflineStorage.saveHotspots(data);
      if (mounted) {
        setState(() {
          _allHotspots = data;
          _lastUpdated = 'Just now';
          _fromCache   = false;
          _applyFilter();
          _isLoading   = false;
        });
      }
    } catch (e) {
      final cached = await OfflineStorage.loadHotspots();
      final label  = await OfflineStorage.getLastSyncLabel();
      if (mounted) {
        setState(() {
          _allHotspots = cached;
          _lastUpdated = cached.isNotEmpty ? 'Cached $label' : 'Could not refresh';
          _fromCache   = true;
          _applyFilter();
          _isLoading   = false;
        });
      }
    }
  }

  // ── Group raw report rows into one summary per cluster ─────────────────────
  // Many verified reports can now share the same `cluster` id (see
  // admin_cubit.dart's K-Means step), so the feed shouldn't show one card
  // per report — it shows one card per zone, with the total case count and
  // how many individual reports fed into it. Reports that haven't been
  // clustered yet (cluster is null — e.g. verified after the last K-Means
  // run) each stay as their own standalone card so nothing goes missing.
  List<Map<String, dynamic>> _buildGroups(List<dynamic> rows) {
    final Map<String, List<Map<String, dynamic>>> byCluster = {};
    for (final r in rows) {
      final row = Map<String, dynamic>.from(r as Map);
      final key = row['cluster'] != null
          ? 'cluster_${row['cluster']}'
          : 'single_${row['id']}';
      byCluster.putIfAbsent(key, () => []).add(row);
    }

    return byCluster.values.map((members) {
      // Newest member represents the group for detail/comments/photo.
      members.sort((a, b) {
        final at = DateTime.tryParse((a['updated_at'] ?? a['created_at'] ?? '').toString());
        final bt = DateTime.tryParse((b['updated_at'] ?? b['created_at'] ?? '').toString());
        if (at == null || bt == null) return 0;
        return bt.compareTo(at);
      });
      final representative = members.first;

      // Most common district label in the group, in case a cluster spans
      // two nearby named areas.
      final districtCounts = <String, int>{};
      for (final m in members) {
        final d = (m['district'] as String?) ?? 'Unknown';
        districtCounts[d] = (districtCounts[d] ?? 0) + 1;
      }
      final topDistrict =
          districtCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

      final totalCases = members.fold<int>(
          0, (sum, m) => sum + ((m['crime_count'] as num?)?.toInt() ?? 0));

      final types = members.map((m) => (m['type'] as String?) ?? 'Hotspot').toSet();
      final typeLabel = types.length == 1 ? types.first : '${types.length} incident types';

      return {
        ...representative,
        'district':     topDistrict,
        'type':         typeLabel,
        'crime_count':  totalCases,      // cluster total — matches the risk-labeling math
        'report_count': members.length,
        'updated_at':   representative['updated_at'] ?? representative['created_at'],
      };
    }).toList();
  }

  void _applyFilter() {
    _allGroups = _buildGroups(_allHotspots);

    Iterable<Map<String, dynamic>> result = _activeFilter == 'All'
        ? _allGroups
        : _allGroups.where((h) => h['risk'] == _activeFilter);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((h) =>
          ((h['district'] as String?) ?? '').toLowerCase().contains(q));
    }

    _filtered = result.toList();
  }

  void _setFilter(String f) => setState(() { _activeFilter = f; _applyFilter(); });

  void _onSearchChanged(String q) => setState(() { _searchQuery = q; _applyFilter(); });

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() { _searchQuery = ''; _applyFilter(); });
  }

  // ── Format helpers ────────────────────────────────────────────────────────
  String _tempoh(String? verifiedAt) {
    if (verifiedAt == null) return '—';
    try {
      final diff = DateTime.now().difference(DateTime.parse(verifiedAt));
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24)   return '${diff.inHours} hours ago';
      if (diff.inDays < 30)    return '${diff.inDays} days ago';
      return '${(diff.inDays / 30).floor()} months ago';
    } catch (_) { return '—'; }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dangerCount  = _allGroups.where((h) => h['risk'] == 'Danger').length;
    final cautionCount = _allGroups.where((h) => h['risk'] == 'Caution').length;
    final safeCount    = _allGroups.where((h) => h['risk'] == 'Safe').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(
            _isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: _isOnline ? Colors.green : Colors.orange,
          ),
        ),
        title: const Text('Alerts',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(children: [
        OfflineBanner(isOnline: _isOnline, lastSynced: _lastUpdated, onRetry: _fetchAlerts),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Alerts',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF22355F))),
              Row(children: [
                Text('· Last updated $_lastUpdated · ${_allHotspots.length} alerts',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                if (_fromCache)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.cloud_off, size: 14, color: Colors.orange),
                  ),
              ]),
            ],
          ),
        ),

        // Search bar — filter by district
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: _buildSearchBar(),
        ),

        // Summary chips
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(children: [
            _summaryChip('All', _allHotspots.length, Colors.blueAccent),
            const SizedBox(width: 8),
            _summaryChip('Danger', dangerCount, Colors.red),
            const SizedBox(width: 8),
            _summaryChip('Caution', cautionCount, Colors.orange),
            const SizedBox(width: 8),
            _summaryChip('Safe', safeCount, Colors.green),
          ]),
        ),

        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B71FE)))
              : _filtered.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: const Color(0xFF3B71FE),
                      onRefresh: _fetchAlerts,
                      child: Container(
                        color: Colors.white,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 120),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) => _buildAlertCard(_filtered[i]),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
      ],
    ),
    child: TextField(
      controller: _searchCtrl,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search by district...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? GestureDetector(
                onTap: _clearSearch,
                child: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 18),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13, color: Color(0xFF22355F)),
    ),
  );

  // ── Summary chip ──────────────────────────────────────────────────────────
  Widget _summaryChip(String label, int count, Color color) {
    final bool sel = _activeFilter == label;
    return GestureDetector(
      onTap: () => _setFilter(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(
              color: sel ? Colors.white : color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$label  $count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: sel ? Colors.white : color)),
        ]),
      ),
    );
  }

  // ── Alert card — Twitter-style feed row ───────────────────────────────────
  Widget _buildAlertCard(Map<String, dynamic> spot) {
    final String district    = spot['district']   as String? ?? 'Unknown';
    final String type        = spot['type']       as String? ?? 'Hotspot';
    final String risk        = spot['risk']       as String? ?? 'Safe';
    final int    count       = (spot['crime_count'] as num?)?.toInt() ?? 0;
    final int    reportCount = (spot['report_count'] as num?)?.toInt() ?? 1;
    final String? verifiedAt = spot['updated_at'] as String? ?? spot['created_at'] as String?;

    final Color rc = risk == 'Danger' ? Colors.red : (risk == 'Caution' ? Colors.orange : Colors.green);
    final IconData icon = risk == 'Danger'
        ? Icons.warning_amber_rounded
        : (risk == 'Caution' ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded);
    final String riskLabel = risk == 'Danger' ? 'High Risk' : (risk == 'Caution' ? 'Caution' : 'Safe Zone');

    return InkWell(
      onTap: () => _showDetail(spot),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // "Avatar" bubble — risk-colored icon instead of a profile photo
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: rc.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: rc, size: 21),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Name row — district acts as the "display name", with a
              // verified badge and relative time, like a tweet header.
              Row(children: [
                Flexible(
                  // ignore: unnecessary_string_interpolations
                  child: Text('$riskLabel',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15, color: (Colors.green)),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 4),
                Text('· ${_tempoh(verifiedAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ]),
              const SizedBox(height: 1),
              Text( type ,
                  style: TextStyle(fontSize: 14, color: Color(0xFF22355F), fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),

              // Body — the incident type reads like the "tweet" text
              Text('At $district',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35)),
              const SizedBox(height: 10),

              // Action row — comment / cases stats, like reply/like counters
              Row(children: [
                _tweetAction(Icons.chat_bubble_outline_rounded, 'Comments'),
                const SizedBox(width: 28),
                _tweetAction(Icons.groups_outlined, '$reportCount reports'),
                const SizedBox(width: 28),
                _tweetAction(Icons.bar_chart_rounded, '$count cases'),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade400),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _tweetAction(IconData icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 15, color: Colors.grey.shade500),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
  ]);

  // ── Detail — opens a dedicated full page (X/Twitter-style) ────────────────
  void _showDetail(Map<String, dynamic> spot) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AlertDetailPage(spot: spot)),
    );
  }

  Widget _buildEmpty() {
    final bool searching = _searchQuery.trim().isNotEmpty;
    final String title = searching
        ? 'No results for "${_searchQuery.trim()}"'
        : (_activeFilter == 'All' ? 'No alerts found' : 'No $_activeFilter alerts');
    final String subtitle = searching ? 'Try a different district name' : 'Pull down to refresh';

    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(searching ? Icons.search_off_rounded : Icons.check_circle_outline,
            size: 64, color: searching ? Colors.grey.shade300 : Colors.green.shade300),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF22355F))),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ]),
    );
  }
}