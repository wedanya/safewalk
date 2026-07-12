import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/connectivity_service.dart';
import '../../shared/offline_storage.dart';
import '../../shared/offline_banner.dart';


class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  List<dynamic> _allHotspots = [];   // same data as map
  List<dynamic> _filtered    = [];   // filtered by selected tab
  bool _isLoading   = true;
  String _lastUpdated = "Fetching...";
  bool _isOnline    = true;
  bool _fromCache   = false;
  String _activeFilter = "All";     // matches map filter chips exactly

  StreamSubscription<bool>? _connectSub;

  // Filter options — same labels as home_map_page chips
  static const List<Map<String, dynamic>> _filters = [
    {'label': 'All',     'color': Colors.blueAccent},
    {'label': 'Danger',  'color': Colors.red},
    {'label': 'Caution', 'color': Colors.orange},
    {'label': 'Safe',    'color': Colors.green},
  ];

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService().isOnline;
    _connectSub = ConnectivityService().onChanged.listen((online) {
      if (mounted) {
        setState(() => _isOnline = online);
        if (online) _fetchAlerts();
      }
    });
    _fetchAlerts();
  }

  @override
  void dispose() {
    _connectSub?.cancel();
    super.dispose();
  }

  // ── FETCH — uses SAME source as home_map_page (all verified hotspots) ────
  Future<void> _fetchAlerts() async {
    setState(() => _isLoading = true);

    if (!_isOnline) {
      // Offline — load from the shared hotspot cache (same as map)
      final cached = await OfflineStorage.loadHotspots();
      final label  = await OfflineStorage.getLastSyncLabel();
      if (mounted) {
        setState(() {
        _allHotspots = cached;
        _lastUpdated = cached.isNotEmpty ? "Cached $label" : "No cache available";
        _fromCache   = true;
        _applyFilter();
        _isLoading   = false;
      });
      }
      return;
    }

    // Online — fetch ALL verified hotspots (same query as map, no source filter)
    try {
      final response = await Supabase.instance.client
          .from('hotspots')
          .select()
          .eq('verified', true)
          .order('crime_count', ascending: false); // highest risk first

      final data = response as List<dynamic>;

      // Save to shared hotspot cache so map benefits too
      if (data.isNotEmpty) await OfflineStorage.saveHotspots(data);

      if (mounted) {
        setState(() {
        _allHotspots = data.isNotEmpty ? data : [];
        _lastUpdated = "Just now";
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
        _lastUpdated = cached.isNotEmpty ? "Cached $label" : "Could not refresh";
        _fromCache   = true;
        _applyFilter();
        _isLoading   = false;
      });
      }
    }
  }

  void _applyFilter() {
    if (_activeFilter == "All") {
      _filtered = List.from(_allHotspots);
    } else {
      _filtered = _allHotspots.where((h) => h['risk'] == _activeFilter).toList();
    }
  }

  void _setFilter(String filter) {
    setState(() {
      _activeFilter = filter;
      _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "Alerts",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Icon(
            _isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: _isOnline ? Colors.green : Colors.orange,
          ),
        ),
      ),
      body: Column(children: [
        // Offline banner
        OfflineBanner(isOnline: _isOnline, lastSynced: _lastUpdated, onRetry: _fetchAlerts),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Recent Alerts",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF22355F))),
              if (_fromCache)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("CACHED", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "• Last updated $_lastUpdated  •  ${_filtered.length} alert${_filtered.length != 1 ? 's' : ''}",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ),

        // ── Filter tabs (same labels as map filter chips) ──────────────────
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _filters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f     = _filters[i];
              final label = f['label'] as String;
              final color = f['color'] as Color;
              final sel   = _activeFilter == label;
              return GestureDetector(
                onTap: () => _setFilter(label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color, width: 1.5),
                    boxShadow: sel
                        // ignore: deprecated_member_use
                        ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0,3))]
                        : [],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (label != 'All') ...[
                      Container(width: 7, height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sel ? Colors.white : color,
                          )),
                      const SizedBox(width: 5),
                    ],
                    Text(label, style: TextStyle(
                      color: sel ? Colors.white : color,
                      fontWeight: FontWeight.bold, fontSize: 12,
                    )),
                    // Count badge
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: sel ? Colors.white.withOpacity(0.25) : color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        label == 'All'
                            ? '${_allHotspots.length}'
                            : '${_allHotspots.where((h) => h['risk'] == label).length}',
                        style: TextStyle(
                          color: sel ? Colors.white : color,
                          fontSize: 10, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // ── Alert list ─────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B71FE)))
              : RefreshIndicator(
                  onRefresh: _fetchAlerts,
                  child: _filtered.isEmpty
                      ? _buildEmpty()
                      : _buildSectionedList(),
                ),
        ),
      ]),
    );
  }

  // ── Sectioned list: Recent (≤30 days) then Past ───────────────────────────
  Widget _buildSectionedList() {
    final now = DateTime.now();

    final recent = _filtered.where((h) {
      final raw = h['created_at'] as String?;
      if (raw == null) return true;
      try { return now.difference(DateTime.parse(raw)).inDays <= 30; }
      catch (_) { return true; }
    }).toList();

    final past = _filtered.where((h) {
      final raw = h['created_at'] as String?;
      if (raw == null) return false;
      try { return now.difference(DateTime.parse(raw)).inDays > 30; }
      catch (_) { return false; }
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        _sectionHeader(Icons.bolt_rounded,    'Recent Alerts', const Color(0xFF3B71FE), recent.length),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          _sectionEmpty('No recent alerts in the last 30 days')
        else
          ...recent.map((h) => _buildHotspotCard(h)),

        if (past.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionHeader(Icons.history_rounded, 'Past Alerts', Colors.grey, past.length),
          const SizedBox(height: 10),
          ...past.map((h) => _buildHotspotCard(h, dimmed: true)),
        ],

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String label, Color color, int count) {
    return Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ),
    ]);
  }

  Widget _sectionEmpty(String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 13)),
  );

  // ── HOTSPOT CARD — mirrors the map marker info ────────────────────────────
  Widget _buildHotspotCard(Map<String, dynamic> spot, {bool dimmed = false}) {
    final String district = spot['district'] as String? ?? 'Unknown';
    final String type     = spot['type']     as String? ?? 'Hotspot';
    final String risk     = spot['risk']     as String? ?? 'Safe';
    final int    count    = (spot['crime_count'] as num?)?.toInt() ?? 0;
    final String source   = spot['source']   as String? ?? 'kmeans';

    final Color riskColor = risk == "Danger"
        ? Colors.red
        : (risk == "Caution" ? Colors.orange : Colors.green);

    final IconData icon = risk == "Danger"
        ? Icons.warning_amber_rounded
        : (risk == "Caution" ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded);

    final String sourceLabel;
    switch (source) {
      case 'pdrm_official':
        sourceLabel = 'Official PDRM';
        break;
      case 'kmeans_clustered':
        sourceLabel = 'AI K-Means';
        break;
      case 'user_report':
      default:
        sourceLabel = 'Community Report';
        break;
    }
    final String riskLabel   = risk == "Danger" ? "HIGH RISK" : (risk == "Caution" ? "CAUTION" : "SAFE ZONE");

    return GestureDetector(
      onTap: () => _showAlertDetail(spot),
      child: Opacity(
      opacity: dimmed ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          // ignore: deprecated_member_use
          boxShadow: dimmed ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Card top — risk colour bar
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: riskColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: riskColor, size: 22),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Risk badge + source
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: riskColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(riskLabel,
                      style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(sourceLabel,
                      style: const TextStyle(color: Color(0xFF7B8BB2), fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 8),

              // District name
              Text(district,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF22355F))),
              const SizedBox(height: 4),
              Text(type, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 10),

              // Stats row
              Row(children: [
                _statChip(Icons.bar_chart_rounded, "$count cases", const Color(0xFF22355F)),
                const SizedBox(width: 8),
                _statChip(Icons.calendar_today_outlined, "2023 Stats", Colors.grey),
              ]),
            ])),
          ]),
        ),
      ]),
      ),
      ),
    );
  }

  void _showAlertDetail(Map<String, dynamic> spot) {
    final String district = spot['district'] as String? ?? 'Unknown';
    final String type     = spot['type']     as String? ?? 'Hotspot';
    final String risk     = spot['risk']     as String? ?? 'Safe';
    final int    count    = (spot['crime_count'] as num?)?.toInt() ?? 0;
    final String? imageUrl = spot['image_url'] as String?;
    final String? notes   = spot['details']  as String?;
    final String? date    = spot['created_at'] as String?;

    String formattedDate = '—';
    if (date != null) {
      try {
        final dt = DateTime.parse(date).toLocal();
        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    formattedDate =
    '${dt.day} ${months[dt.month - 1]} ${dt.year} '
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';      } catch (_) {}
    }

    final Color riskColor = risk == 'Danger' ? Colors.red : (risk == 'Caution' ? Colors.orange : Colors.green);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(controller: ctrl, padding: const EdgeInsets.all(24), children: [
            Center(child: Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            // Risk badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: riskColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(risk == 'Danger' ? 'HIGH RISK' : risk == 'Caution' ? 'CAUTION' : 'SAFE ZONE',
                  style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 12),
            Text(district, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF22355F))),
            const SizedBox(height: 4),
            Text(type, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 12),
            _detailRow(Icons.bar_chart_rounded,        'Total Cases (2023)', '$count cases'),
            _detailRow(Icons.calendar_today_outlined,  'Date',               formattedDate),
            if (notes != null && notes.isNotEmpty)
              _detailRow(Icons.notes_outlined,         'Notes',              notes),
            _detailRow(Icons.info_outline,             'Risk Level',
              risk == 'Danger'
                ? 'High crime area (300+ cases). Stay alert and avoid isolated areas.'
                : risk == 'Caution'
                  ? 'Moderate crime (100–299 cases). Be aware of surroundings.'
                  : 'Low crime area (fewer than 100 cases). Relatively safe.'),
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Photo Evidence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF22355F))),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 80, color: Colors.grey.shade100,
                    child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)))),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: Colors.grey),
      const SizedBox(width: 8),
      Text('\$label: ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF22355F), fontWeight: FontWeight.w600, fontSize: 12))),
    ]),
  );

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
        const SizedBox(height: 16),
        Text(
          _activeFilter == "All" ? "No alerts found" : "No $_activeFilter alerts",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF22355F)),
        ),
        const SizedBox(height: 8),
        const Text("Pull down to refresh", style: TextStyle(color: Colors.grey, fontSize: 13)),
      ]),
    );
  }
}