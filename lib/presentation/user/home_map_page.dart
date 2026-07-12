import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/connectivity_service.dart';
import '../../shared/offline_storage.dart';

class HomeMapPage extends StatefulWidget {
  const HomeMapPage({super.key});

  @override
  State<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends State<HomeMapPage> {
  // ── Mapbox ────────────────────────────────────────────────────────────────
  static const String _mapboxToken =
      'pk.eyJ1Ijoicnl1bCIsImEiOiJjbXI2NnZ3enUwYzVkMzBzOWQxbmU2dHo5In0.Hw76wVVxC8HmbbTHPtObWw';

  mapbox.MapboxMap? _mapboxMap;

  // ── Map styles ────────────────────────────────────────────────────────────
  int _mapStyle = 0; // 0=Dark 1=Light 2=Satellite
  bool get _isDarkMode => _mapStyle == 0;

  String get _styleUri {
    switch (_mapStyle) {
      case 1: return mapbox.MapboxStyles.LIGHT;
      case 2: return mapbox.MapboxStyles.SATELLITE_STREETS;
      default: return mapbox.MapboxStyles.DARK;
    }
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  String _selectedRisk = 'All';
  List<dynamic> _allData = [];
  bool _isLoading = true;
  bool _isOnline  = true;
  String _lastSynced = '';

  // ── Location ──────────────────────────────────────────────────────────────
  Position? _userPosition;
  String _locationStatus      = 'Locating...';
  Color  _locationStatusColor = Colors.grey;
  StreamSubscription<Position>? _positionSub;

  // ── Geofence ──────────────────────────────────────────────────────────────
  double _geofenceRadiusMetres = 5000;
  bool   _alertsEnabled = true;
  final Map<String, DateTime> _districtCooldowns = {};
  static const Duration _alertCooldown = Duration(minutes: 10);

  // ── Connectivity ──────────────────────────────────────────────────────────
  StreamSubscription<bool>? _connectivitySub;
  RealtimeChannel? _realtimeChannel;

  // ── Fallback data (real 2023 crime data) ──────────────────────────────────
  static const List<Map<String, dynamic>> _localHotspots = [
    {'district': 'Kuala Terengganu', 'lat': 5.3302,  'lng': 103.1408, 'risk': 'Danger',  'crime_count': 416,  'type': 'AI-Clustered Hotspot'},
    {'district': 'Kemaman',          'lat': 4.2333,  'lng': 103.4167, 'risk': 'Danger',  'crime_count': 315,  'type': 'AI-Clustered Hotspot'},
    {'district': 'Besut',            'lat': 5.7956,  'lng': 102.5779, 'risk': 'Caution', 'crime_count': 230,  'type': 'AI-Clustered Hotspot'},
    {'district': 'Dungun',           'lat': 4.7500,  'lng': 103.4167, 'risk': 'Caution', 'crime_count': 173,  'type': 'AI-Clustered Hotspot'},
    {'district': 'Marang',           'lat': 5.2000,  'lng': 103.2167, 'risk': 'Caution', 'crime_count': 102,  'type': 'AI-Clustered Hotspot'},
    {'district': 'Hulu Terengganu',  'lat': 5.0833,  'lng': 102.7833, 'risk': 'Safe',    'crime_count': 94,   'type': 'AI-Clustered Hotspot'},
    {'district': 'Setiu',            'lat': 5.6833,  'lng': 102.6833, 'risk': 'Safe',    'crime_count': 40,   'type': 'AI-Clustered Hotspot'},
  ];

  @override
  void initState() {
    super.initState();
    // Set Mapbox access token
    mapbox.MapboxOptions.setAccessToken(_mapboxToken);

    _isOnline = ConnectivityService().isOnline;
    _connectivitySub = ConnectivityService().onChanged.listen((online) {
      if (mounted) {
        setState(() => _isOnline = online);
        if (online) _fetchData();
      }
    });
    _loadGeofencePrefs().then((_) => _startLocationTracking());
    _fetchData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _positionSub?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // ── Geofence prefs ────────────────────────────────────────────────────────
  Future<void> _loadGeofencePrefs() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final data = await Supabase.instance.client
          .from('profiles')
          .select('alert_enabled, geofence_radius_km')
          .eq('id', uid)
          .maybeSingle();
      if (mounted && data != null) {
        setState(() {
          _alertsEnabled        = (data['alert_enabled'] as bool?) ?? true;
          _geofenceRadiusMetres = (((data['geofence_radius_km'] as num?)?.toDouble()) ?? 5.0) * 1000;
        });
      }
    } catch (e) {
      dev.log('[Prefs] $e');
    }
  }

  // ── Realtime ──────────────────────────────────────────────────────────────
  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('public:hotspots')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'hotspots',
          callback: (payload) {
            final verified = payload.newRecord['verified'];
            if (payload.eventType == PostgresChangeEvent.delete ||
                verified == true) {
              _fetchData();
            }
          },
        )
        .subscribe();
  }

  // ── Fetch data ────────────────────────────────────────────────────────────
  Future<void> _fetchData() async {
    if (!_isOnline) {
      final cached = await OfflineStorage.loadHotspots();
      final label  = await OfflineStorage.getLastSyncLabel();
      if (mounted) {
        setState(() {
          _allData    = cached.isNotEmpty ? cached : _localHotspots;
          _lastSynced = cached.isNotEmpty ? label : 'built-in data';
          _isLoading  = false;
        });
        await _plotHotspots();
      }
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('hotspots')
          .select()
          .eq('verified', true);
      final data = (response as List<dynamic>).isNotEmpty
          ? response
          : _localHotspots;
      await OfflineStorage.saveHotspots(data);
      final label = await OfflineStorage.getLastSyncLabel();
      if (mounted) {
        setState(() {
          _allData    = data;
          _lastSynced = label;
          _isLoading  = false;
        });
        await _plotHotspots();
      }
    } catch (e) {
      dev.log('[Map] $e');
      final cached = await OfflineStorage.loadHotspots();
      final label  = await OfflineStorage.getLastSyncLabel();
      if (mounted) {
        setState(() {
          _allData    = cached.isNotEmpty ? cached : _localHotspots;
          _lastSynced = cached.isNotEmpty ? label : 'built-in data';
          _isLoading  = false;
        });
        await _plotHotspots();
      }
    }
  }

  // ── Plot hotspots using Mapbox CircleAnnotations ──────────────────────────
  Future<void> _plotHotspots() async {
    final map = _mapboxMap;
    if (map == null) return;

    // Clear existing annotations
    await map.annotations.createCircleAnnotationManager().then((manager) async {
      await manager.deleteAll();
    });

    final circleManager = await map.annotations.createCircleAnnotationManager();

    final filtered = _allData.where((s) =>
        _selectedRisk == 'All' || _selectedRisk == (s['risk'] ?? 'Safe'));

    for (final spot in filtered) {
      final risk     = spot['risk']      as String? ?? 'Safe';
      final lat      = (spot['lat']      as num).toDouble();
      final lng      = (spot['lng']      as num).toDouble();
      final district = spot['district']  as String? ?? 'Unknown';
      final count    = (spot['crime_count'] as num?)?.toInt() ?? 0;
      final type     = spot['type']      as String? ?? 'AI Hotspot';

      final color = risk == 'Danger'
          ? const Color(0xFFFF3B30)
          : risk == 'Caution'
              ? const Color(0xFFFF9500)
              : const Color(0xFF34C759);

      final double radius = risk == 'Danger' ? 20 : risk == 'Caution' ? 15 : 10;

      // Glow ring
      await circleManager.create(mapbox.CircleAnnotationOptions(
        geometry: mapbox.Point(
          coordinates: mapbox.Position(lng, lat),
        ),
        circleRadius: radius * 2.5,
        circleColor: color.toARGB32(),
        circleOpacity: 0.2,
        circleStrokeWidth: 0,
        circleStrokeOpacity: 0,
      ));

      // Core circle
      final core = await circleManager.create(mapbox.CircleAnnotationOptions(
        geometry: mapbox.Point(
          coordinates: mapbox.Position(lng, lat),
        ),
        circleRadius: radius,
        circleColor: color.toARGB32(),
        circleOpacity: 0.9,
        circleStrokeWidth: 2,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeOpacity: 0.9,
      ));

      // Tap on core circle shows detail sheet
      circleManager.addOnCircleAnnotationClickListener(
        _CircleTapListener(
          annotationId: core.id,
          onTap: () => _showDetails(district, type, risk, count),
        ),
      );
    }
  }

  // ── Location tracking — Waze-style follow + tilt ──────────────────────────
  Future<void> _startLocationTracking() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationStatus = 'Location denied');
        return;
      }

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) async {
        if (!mounted) return;
        setState(() => _userPosition = pos);
        _checkGeofence(pos);

        // Waze-style: follow user, tilt 45°, rotate to heading
        await _mapboxMap?.flyTo(
          mapbox.CameraOptions(
            center: mapbox.Point(
              coordinates: mapbox.Position(pos.longitude, pos.latitude),
            ),
            zoom: 15.5,
            pitch: 45,
            bearing: pos.heading,
          ),
          mapbox.MapAnimationOptions(duration: 1000),
        );
      });
    } catch (e) {
      dev.log('[Location] $e');
    }
  }

  // ── Geofence ──────────────────────────────────────────────────────────────
  void _checkGeofence(Position userPos) {
    if (!_alertsEnabled) return;

    String? nearestRisk;
    String? nearestDistrict;
    int nearestDist = 999999;

    for (var spot in _allData) {
      final risk = spot['risk'] as String? ?? 'Safe';
      if (risk == 'Safe') continue;
      final d = Geolocator.distanceBetween(
        userPos.latitude, userPos.longitude,
        (spot['lat'] as num).toDouble(),
        (spot['lng'] as num).toDouble(),
      ).toInt();
      if (d <= _geofenceRadiusMetres && d < nearestDist) {
        nearestDist     = d;
        nearestRisk     = risk;
        nearestDistrict = spot['district'] as String?;
      }
    }

    if (nearestRisk == 'Danger' && nearestDistrict != null) {
      final safeDistrict = nearestDistrict;
      setState(() {
        _locationStatus      = '⚠️ Near $safeDistrict!';
        _locationStatusColor = Colors.red;
      });
      _showGeofenceAlert(safeDistrict, nearestDist);
    } else if (nearestRisk == 'Caution' && nearestDistrict != null) {
      setState(() {
        _locationStatus      = '⚡ Caution: $nearestDistrict';
        _locationStatusColor = Colors.orange;
      });
    } else {
      setState(() {
        _locationStatus      = '✅ You are in a Safe Zone';
        _locationStatusColor = Colors.green;
      });
    }
  }

  void _showGeofenceAlert(String district, int distM) {
    final now  = DateTime.now();
    final last = _districtCooldowns[district];
    if (last != null && now.difference(last) < _alertCooldown) return;
    _districtCooldowns[district] = now;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          SizedBox(width: 10),
          Text('DANGER ZONE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
        ]),
        content: Text(
          'You are approximately ${distM ~/ 1000} km from $district, '
          'a high-crime area.\n\nPlease stay alert and avoid isolated areas.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Detail bottom sheet ───────────────────────────────────────────────────
  void _showDetails(String district, String type, String risk, int count) {
    final rc = risk == 'Danger'
        ? Colors.red
        : risk == 'Caution'
            ? Colors.orange
            : Colors.green;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(children: [
            CircleAvatar(
              backgroundColor: rc.withValues(alpha: 0.15),
              child: Icon(Icons.shield, color: rc),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(risk.toUpperCase(),
                  style: TextStyle(
                      color: rc,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.5)),
              Text(district,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode
                          ? Colors.white
                          : const Color(0xFF22355F))),
            ]),
          ]),
          const SizedBox(height: 14),
          Divider(color: _isDarkMode ? Colors.white12 : Colors.grey.shade200),
          const SizedBox(height: 8),
          _row(Icons.category_outlined,   'Incident Type',          type),
          const SizedBox(height: 8),
          _row(Icons.bar_chart_rounded,   'Recorded Cases (2023)',  '$count cases'),
          const SizedBox(height: 8),
          _row(Icons.verified_outlined,   'Clustering Method',      'K-Means Algorithm (data.gov.my)'),
          const SizedBox(height: 12),
          // Risk level explanation card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: rc.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rc.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_riskIcon(risk), color: rc, size: 16),
                const SizedBox(width: 6),
                Text('What does ${risk.toUpperCase()} mean?',
                    style: TextStyle(color: rc, fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
              const SizedBox(height: 6),
              Text(_riskExplanation(risk, count),
                  style: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? Colors.white70 : Colors.black87,
                      height: 1.5)),
            ]),
          ),
          const SizedBox(height: 8),
          _row(Icons.cloud_done_outlined, 'Data',
              _isOnline ? 'Live from Supabase' : 'Cached offline copy'),
        ]),
      ),
    );
  }

  IconData _riskIcon(String risk) {
    if (risk == 'Danger') return Icons.warning_amber_rounded;
    if (risk == 'Caution') return Icons.info_rounded;
    return Icons.check_circle_rounded;
  }

  String _riskExplanation(String risk, int count) {
    if (risk == 'Danger') {
      return '🔴 This district recorded $count criminal cases in 2023, placing it in the highest risk cluster identified by K-Means. '
          'Types include assault and property crime. '
          'Avoid walking alone at night and stay in well-lit public areas.';
    } else if (risk == 'Caution') {
      return '🟡 This district recorded $count criminal cases in 2023, placing it in the moderate risk cluster. '
          'Crime occurs but is less frequent than Danger zones. '
          'Stay aware of your surroundings, especially in isolated areas.';
    } else {
      return '🟢 This district recorded $count criminal cases in 2023 — the lowest cluster identified by K-Means. '
          'It is relatively safer than other districts in Terengganu. '
          'Standard safety precautions still apply.';
    }
  }

  Widget _row(IconData icon, String label, String value) => Row(children: [
    Icon(icon, size: 16,
        color: _isDarkMode ? Colors.white38 : Colors.grey),
    const SizedBox(width: 8),
    Text('$label: ',
        style: TextStyle(
            color: _isDarkMode ? Colors.white54 : Colors.grey, fontSize: 12)),
    Expanded(
      child: Text(value,
          style: TextStyle(
              color: _isDarkMode ? Colors.white : const Color(0xFF22355F),
              fontWeight: FontWeight.w600,
              fontSize: 12)),
    ),
  ]);

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final userPos = _userPosition;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [

        // ── Mapbox Map — true 3D with tilt ───────────────────────────────
        mapbox.MapWidget(
          key: const ValueKey('mapbox-map'),
          styleUri: _styleUri,
          cameraOptions: mapbox.CameraOptions(
            center: mapbox.Point(
              coordinates: mapbox.Position(103.1408, 5.3302),
            ),
            zoom: 9.5,
            pitch: 45.0,   // 3D tilt like Waze
            bearing: 0.0,
          ),
          onMapCreated: (controller) async {
            _mapboxMap = controller;

            // Enable location puck (blue dot)
            await controller.location.updateSettings(
              mapbox.LocationComponentSettings(
                enabled: true,
                pulsingEnabled: true,
                pulsingColor: Colors.blue.value,
                locationPuck: mapbox.LocationPuck(
                  locationPuck2D: mapbox.DefaultLocationPuck2D(),
                ),
              ),
            );

            // Enable 3D buildings
            await controller.style.addLayer(
              mapbox.FillExtrusionLayer(
                id: '3d-buildings',
                sourceId: 'composite',
              )
              ..sourceLayer = 'building'
              ..filter = ['==', 'extrude', 'true']
              ..minZoom = 15
              ..fillExtrusionColor = _isDarkMode
                  ? Colors.blueGrey.shade800.toARGB32()
                  : Colors.grey.shade300.toARGB32()
              ..fillExtrusionHeight = 0
              ..fillExtrusionBase = 0
              ..fillExtrusionHeightExpression = [
                'interpolate', ['linear'], ['zoom'],
                15, 0, 15.05, ['get', 'height']
              ]
              ..fillExtrusionBaseExpression = [
                'interpolate', ['linear'], ['zoom'],
                15, 0, 15.05, ['get', 'min_height']
              ]
              ..fillExtrusionOpacity = 0.7,
            );

            await _plotHotspots();
          },
          onStyleLoadedListener: (_) async {
            await _plotHotspots();
          },
        ),

        // ── LIVE / OFFLINE badge ──────────────────────────────────────────
        Positioned(
          top: 60, left: 0, right: 0,
          child: Center(child: _buildLiveBadge()),
        ),

        // ── Risk status banner ────────────────────────────────────────────
        Positioned(
          top: 108, left: 20, right: 20,
          child: Center(child: _buildLocationBanner()),
        ),

        // ── Style switcher ────────────────────────────────────────────────
        Positioned(top: 55, right: 20, child: _buildStyleSwitcher()),

        // ── Offline chip ──────────────────────────────────────────────────
        if (!_isOnline)
          Positioned(
            top: 155, left: 16, right: 16,
            child: _buildOfflineChip(),
          ),

        // ── Recenter + follow button ──────────────────────────────────────
        if (_userPosition != null)
          Positioned(
            bottom: 160, right: 20,
            child: GestureDetector(
              onTap: () async {
                final pos = _userPosition;
                if (pos == null) return;
                await _mapboxMap?.flyTo(
                  mapbox.CameraOptions(
                    center: mapbox.Point(
                      coordinates: mapbox.Position(
                          pos.longitude, pos.latitude),
                    ),
                    zoom: 15.5,
                    pitch: 45,
                    bearing: pos.heading,
                  ),
                  mapbox.MapAnimationOptions(duration: 800),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isDarkMode
                      ? const Color(0xFF2D2D2D)
                      : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8)
                  ],
                ),
                child: const Icon(Icons.navigation_rounded,
                    color: Colors.blue, size: 22),
              ),
            ),
          ),

        // ── Filter chips ──────────────────────────────────────────────────
        Positioned(
          bottom: 95, left: 20, right: 20,
          child: _buildFilterCard(),
        ),

        if (_isLoading)
          const Center(
              child: CircularProgressIndicator(color: Colors.red)),
      ]),
    );
  }

  // ── UI Widgets ────────────────────────────────────────────────────────────

  Widget _buildLiveBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
    decoration: BoxDecoration(
      color: _isOnline
          ? Colors.red.withValues(alpha: 0.85)
          : Colors.grey.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: (_isOnline ? Colors.red : Colors.grey).withValues(alpha: 0.4),
          blurRadius: 15,
        )
      ],
    ),
    child: Text(
      _isOnline ? 'LIVE' : 'OFFLINE',
      style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0),
    ),
  );

  Widget _buildLocationBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: _isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      border: Border.all(color: _locationStatusColor, width: 1.5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.my_location, color: _locationStatusColor, size: 14),
      const SizedBox(width: 6),
      Text(_locationStatus,
          style: TextStyle(
              color: _locationStatusColor,
              fontWeight: FontWeight.w700,
              fontSize: 11)),
    ]),
  );

  Widget _buildOfflineChip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF2D2D2D),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off_rounded, color: Colors.white60, size: 14),
      const SizedBox(width: 6),
      Text(
        _lastSynced.isNotEmpty
            ? 'Offline · Cached $_lastSynced'
            : 'Offline · Built-in data',
        style: const TextStyle(color: Colors.white60, fontSize: 11),
      ),
    ]),
  );

  Widget _buildStyleSwitcher() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _styleBtn(icon: Icons.dark_mode_rounded,     index: 0, tooltip: 'Dark 3D'),
      const SizedBox(height: 8),
      _styleBtn(icon: Icons.light_mode_rounded,    index: 1, tooltip: 'Light 3D'),
      const SizedBox(height: 8),
      _styleBtn(icon: Icons.satellite_alt_rounded, index: 2, tooltip: 'Satellite'),
    ]);
  }

  Widget _styleBtn({
    required IconData icon,
    required int index,
    required String tooltip,
  }) {
    final bool active = _mapStyle == index;
    return GestureDetector(
      onTap: () async {
        setState(() => _mapStyle = index);
        await _mapboxMap?.loadStyleURI(_styleUri);
      },
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF3B71FE)
                : (_isDarkMode ? const Color(0xFF2D2D2D) : Colors.white),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8)
            ],
          ),
          child: Icon(icon,
              color: active
                  ? Colors.white
                  : (_isDarkMode
                      ? Colors.white70
                      : const Color(0xFF22355F)),
              size: 20),
        ),
      ),
    );
  }

  Widget _buildFilterCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      borderRadius: BorderRadius.circular(25),
      boxShadow: [
        BoxShadow(
            color: _isDarkMode ? Colors.black54 : Colors.black12,
            blurRadius: 10)
      ],
    ),
    child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
      _chip('Safe',    Colors.green),
      _chip('Caution', Colors.orange),
      _chip('Danger',  Colors.red),
      _chip('All',     Colors.blueAccent),
    ]),
  );

  Widget _chip(String label, Color color) {
    final bool sel = _selectedRisk == label;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedRisk = label);
        _plotHotspots();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ),
    );
  }
}

// ── Circle tap listener helper ────────────────────────────────────────────────

class _CircleTapListener
    extends mapbox.OnCircleAnnotationClickListener {
  final String annotationId;
  final VoidCallback onTap;

  _CircleTapListener({required this.annotationId, required this.onTap});

  @override
  void onCircleAnnotationClick(mapbox.CircleAnnotation annotation) {
    if (annotation.id == annotationId) onTap();
  }
}