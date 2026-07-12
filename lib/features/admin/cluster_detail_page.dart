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
  final MapController _mapController = MapController();

  static const List<Color> _clusterColors = [
    Colors.red, Colors.blue, Colors.green,
    Colors.purple, Colors.orange, Colors.teal,
  ];

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
          .select('id, district, lat, lng, cluster, crime_count, type')
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
                            final color = _clusterColors[cluster % _clusterColors.length];
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
                                      ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 12)]
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

                  // ── Legend row ─────────────────────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _grouped.keys.where((k) => k >= 0).map((k) {
                          final color = _clusterColors[k % _clusterColors.length];
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Row(children: [
                              CircleAvatar(radius: 8, backgroundColor: color,
                                child: Text('${k+1}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                              const SizedBox(width: 6),
                              Text('Cluster ${k + 1}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // ── Cluster list — tap to fly on map ───────────────────
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _grouped.entries
                            .where((e) => e.key >= 0)
                            .map((e) => _buildClusterCard(e.key, e.value))
                            .toList(),
                      ),
                    ),
                  ),
                ]),
    );
  }

  Widget _buildClusterCard(int cluster, List<Map<String, dynamic>> members) {
    final color = _clusterColors[cluster % _clusterColors.length];
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
              color: isFocused ? color.withOpacity(0.2) : Colors.black.withOpacity(0.05),
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
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              CircleAvatar(backgroundColor: color, radius: 18,
                child: Text('${cluster + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cluster ${cluster + 1}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                Text('${members.length} hotspot${members.length != 1 ? 's' : ''} · $totalCrimes total cases',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ])),
              // Tap hint
              Icon(Icons.location_on_rounded, color: color.withOpacity(0.5), size: 20),
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