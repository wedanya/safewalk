import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClusterDetailPage extends StatefulWidget {
  const ClusterDetailPage({super.key});
  @override
  State<ClusterDetailPage> createState() => _ClusterDetailPageState();
}

class _ClusterDetailPageState extends State<ClusterDetailPage> {
  List<Map<String, dynamic>> _hotspots = [];
  bool _isLoading = true;
  int? _focusedCluster; // which cluster to fly to on map
  String _riskFilter = 'All'; // All / Danger / Caution / Safe
  final MapController _mapController = MapController();

  static const Color _dangerColor  = Color(0xFFFF3B30);
  static const Color _cautionColor = Color(0xFFFF9500);
  static const Color _safeColor    = Color(0xFF34C759);

  Color _riskColor(String? risk) {
    switch (risk) {
      case 'Danger':  return _dangerColor;
      case 'Caution': return _cautionColor;
      default:        return _safeColor;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('hotspots')
          .select('id, district, lat, lng, cluster, crime_count, type, risk')
          .eq('verified', true)
          .order('cluster');
      setState(() {
        _hotspots = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Map<int, List<Map<String, dynamic>>> get _grouped {
    final map = <int, List<Map<String, dynamic>>>{};
    for (final h in _hotspots) {
      final key = (h['cluster'] as int?) ?? -1;
      map.putIfAbsent(key, () => []).add(h);
    }
    return map;
  }

  String _clusterRisk(List<Map<String, dynamic>> members) =>
      members.isNotEmpty ? (members.first['risk'] as String? ?? 'Safe') : 'Safe';

  // Cluster entries after applying the selected risk filter chip.
  List<MapEntry<int, List<Map<String, dynamic>>>> get _filteredEntries {
    final entries = _grouped.entries.where((e) => e.key >= 0).toList();
    if (_riskFilter == 'All') return entries;
    return entries.where((e) => _clusterRisk(e.value) == _riskFilter).toList();
  }

  // Compute centroid of a cluster
  LatLng _centroid(List<Map<String, dynamic>> members) {
    final lat = members.map((m) => (m['lat'] as num).toDouble()).reduce((a, b) => a + b) / members.length;
    final lng = members.map((m) => (m['lng'] as num).toDouble()).reduce((a, b) => a + b) / members.length;
    return LatLng(lat, lng);
  }

  void _flyToCluster(int cluster, List<Map<String, dynamic>> members) {
    final center = _centroid(members);
    _mapController.move(center, 9.5);
    setState(() => _focusedCluster = cluster);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Cluster Details',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.blue), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : _hotspots.isEmpty
              ? _buildEmpty()
              : Column(children: [

                  // ── Map ────────────────────────────────────────────────
                  SizedBox(
                    height: 240,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: const MapOptions(
                        initialCenter: LatLng(5.3302, 103.1148),
                        initialZoom: 8.5,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                        ),
                        MarkerLayer(
                          markers: _hotspots.map((h) {
                            final cluster = (h['cluster'] as int?) ?? 0;
                            final color = _riskColor(h['risk'] as String?);
                            final isFocused = _focusedCluster == cluster;
                            return Marker(
                              point: LatLng(
                                (h['lat'] as num).toDouble(),
                                (h['lng'] as num).toDouble(),
                              ),
                              width: isFocused ? 48 : 36,
                              height: isFocused ? 48 : 36,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                  border: Border.all(color: Colors.white, width: isFocused ? 3 : 2),
                                  boxShadow: isFocused
                                      ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12)]
                                      : [],
                                ),
                                child: Center(
                                  child: Text('${cluster + 1}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // ── Risk filter chips ────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _riskFilterChip('All', Colors.blueAccent, Icons.apps_rounded),
                        const SizedBox(width: 8),
                        _riskFilterChip('Danger', _dangerColor, Icons.warning_amber_rounded),
                        const SizedBox(width: 8),
                        _riskFilterChip('Caution', _cautionColor, Icons.info_rounded),
                        const SizedBox(width: 8),
                        _riskFilterChip('Safe', _safeColor, Icons.check_circle_rounded),
                      ]),
                    ),
                  ),

                  // ── Cluster list — tap to fly on map ───────────────────
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: _filteredEntries.isEmpty
                          ? _buildFilterEmpty()
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: _filteredEntries
                                  .map((e) => _buildClusterCard(e.key, e.value))
                                  .toList(),
                            ),
                    ),
                  ),
                ]),
    );
  }

  Widget _riskFilterChip(String label, Color color, IconData icon) {
    final bool selected = _riskFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _riskFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.25),
            width: 1.3,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5)),
        ]),
      ),
    );
  }

  Widget _buildFilterEmpty() {
    final color = _riskFilter == 'All' ? Colors.grey : _riskColor(_riskFilter);
    return ListView(
      // Keeps pull-to-refresh working even when the filtered list is empty
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 120),
        Center(
          child: Column(children: [
            Icon(Icons.filter_alt_off_rounded, size: 56, color: color.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No $_riskFilter zones',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          ]),
        ),
      ],
    );
  }

  Widget _buildClusterCard(int cluster, List<Map<String, dynamic>> members) {
    final risk = members.isNotEmpty ? members.first['risk'] as String? : null;
    final color = _riskColor(risk);
    final totalCrimes = members.fold<int>(0,
        (sum, h) => sum + ((h['crime_count'] as num?)?.toInt() ?? 0));
    final isFocused = _focusedCluster == cluster;

    return GestureDetector(
      onTap: () => _flyToCluster(cluster, members),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isFocused ? Border.all(color: color, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: isFocused ? color.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
              blurRadius: isFocused ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              CircleAvatar(backgroundColor: color, radius: 18,
                child: Text('${cluster + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Zone ${cluster + 1}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text((risk ?? 'Safe').toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ]),
                Text('${members.length} report${members.length != 1 ? 's' : ''} · $totalCrimes total cases',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ])),
              // Tap hint
              Icon(Icons.location_on_rounded, color: color.withValues(alpha: 0.5), size: 20),
            ]),
          ),
          // Members
          ...members.map((h) => ListTile(
            dense: true,
            leading: Icon(Icons.location_on, color: color, size: 18),
            title: Text(h['district'] as String? ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(h['type'] as String? ?? 'Hotspot',
                style: const TextStyle(fontSize: 12)),
            trailing: Text(
              '${(h['crime_count'] as num?)?.toInt() ?? 0} cases',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          )),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.scatter_plot_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text('No clusters yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        const Text('Run K-Means on the Algorithm tab first.',
            style: TextStyle(color: Colors.grey)),
      ]),
    );
  }
}