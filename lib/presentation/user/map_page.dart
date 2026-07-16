import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/connectivity_service.dart';
import '../../shared/offline_storage.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // ── Mapbox ────────────────────────────────────────────────────────────────
  static const String _mapboxToken =
      'pk.eyJ1Ijoicnl1bCIsImEiOiJjbXI2NnZ3enUwYzVkMzBzOWQxbmU2dHo5In0.Hw76wVVxC8HmbbTHPtObWw';

  mapbox.MapboxMap? _mapboxMap;
  mapbox.CircleAnnotationManager? _circleManager;
  mapbox.PointAnnotationManager?  _textManager; // cluster count labels
  int _plotGeneration = 0; // guards against overlapping _plotHotspots() calls
  bool _clickListenerAttached = false;
  final Map<String, Map<String, dynamic>> _annotationClusters = {};

  // ── Map styles ────────────────────────────────────────────────────────────
  // Seeded once from the clock on launch (7pm–7am = dark); after that, the
  // style switcher buttons are a manual override and nothing auto-changes it
  // again mid-session.
  int _mapStyle = _isNightNow() ? 0 : 1; // 0=Dark 1=Light
  bool get _isDarkMode => _mapStyle == 0;

  static bool _isNightNow() {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 7;
  }

  String get _styleUri {
    switch (_mapStyle) {
      case 1: return mapbox.MapboxStyles.LIGHT;
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
  bool _followMode = true; // camera keeps recentering on you while true

  // ── Geofence ──────────────────────────────────────────────────────────────
  double _geofenceRadiusMetres = 5000;
  bool   _alertsEnabled = true;
  final Map<String, DateTime> _districtCooldowns = {};
  static const Duration _alertCooldown = Duration(minutes: 10);

  // ── Connectivity ──────────────────────────────────────────────────────────
  StreamSubscription<bool>? _connectivitySub;
  RealtimeChannel? _realtimeChannel;

  // The historical government dataset is fixed to 2023 — this stays a
  // constant since it's a specific published dataset, not "this year".
  // Community reports, by contrast, get their year from their own
  // created_at timestamp since those keep coming in over time.
  static const int _govDatasetYear = 2023;

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

  // ── 3D buildings layer — must be re-added after EVERY style load, since
  // loadStyleURI() (used by the dark/light toggle) reloads the entire style
  // and wipes out any custom layer added before it. ─────────────────────────
  Future<void> _add3DBuildingsLayer(mapbox.MapboxMap map) async {
    try {
      final exists = await map.style.styleLayerExists('3d-buildings');
      if (exists) return; // already there — avoid a duplicate-id error
    } catch (_) {
      // If the check itself isn't supported on this SDK version, fall
      // through and just try to add it — a duplicate-id error here is
      // safer to ignore than silently never re-adding the layer.
    }

    try {
      await map.style.addLayer(
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
    } catch (e) {
      dev.log('[3D Buildings] $e');
    }
  }

  // ── Cluster nearby points so Kuala Terengganu (lots of close reports)
  // doesn't turn into an overlapping mess of circles ───────────────────────
  static const double _clusterGridDegrees = 0.006; // ≈ 650m grid cells

  List<Map<String, dynamic>> _buildClusters(Iterable<dynamic> spots) {
    final Map<String, List<dynamic>> buckets = {};
    for (final s in spots) {
      final lat = (s['lat'] as num).toDouble();
      final lng = (s['lng'] as num).toDouble();
      final key = '${(lat / _clusterGridDegrees).round()}_${(lng / _clusterGridDegrees).round()}';
      buckets.putIfAbsent(key, () => []).add(s);
    }

    const riskRank = {'Danger': 2, 'Caution': 1, 'Safe': 0};

    return buckets.values.map((members) {
      double latSum = 0, lngSum = 0;
      String worstRisk = 'Safe';
      int totalCases = 0;

      for (final m in members) {
        latSum += (m['lat'] as num).toDouble();
        lngSum += (m['lng'] as num).toDouble();
        final r = m['risk'] as String? ?? 'Safe';
        if ((riskRank[r] ?? 0) > (riskRank[worstRisk] ?? 0)) worstRisk = r;
        totalCases += (m['crime_count'] as num?)?.toInt() ?? 0;
      }

      return {
        'lat': latSum / members.length,
        'lng': lngSum / members.length,
        'risk': worstRisk,
        'count': totalCases,
        'members': members,
      };
    }).toList();
  }

  // ── Plot hotspots using Mapbox CircleAnnotations ──────────────────────────
  Future<void> _plotHotspots() async {
    final map = _mapboxMap;
    if (map == null) return;

    // Guard against overlapping calls — filtering, realtime updates, and
    // style reloads can all trigger this in quick succession. Without this,
    // an older call can still be mid-flight (creating circles/labels) after
    // a newer call already cleared and started its own pass, leaving stray
    // orphaned annotations like a floating count label with no circle.
    final myGeneration = ++_plotGeneration;

    // Reuse the SAME managers every time — creating a brand-new manager on
    // every call meant .deleteAll() only cleared whichever fresh, empty
    // manager it just made, never the one holding the actual markers.
    _circleManager ??= await map.annotations.createCircleAnnotationManager();
    _textManager   ??= await map.annotations.createPointAnnotationManager();
    if (myGeneration != _plotGeneration) return; // a newer call already started
    final circleManager = _circleManager!;
    final textManager   = _textManager!;

    // A single shared click listener, registered once — Mapbox's circle
    // manager only keeps ONE active listener at a time, so calling
    // addOnCircleAnnotationClickListener() again per-marker (the old code
    // did this inside the loop) just silently replaced the previous one.
    // Only the last marker plotted ever actually responded to taps.
    if (!_clickListenerAttached) {
      _clickListenerAttached = true;
      circleManager.addOnCircleAnnotationClickListener(
        _ClusterClickRouter(
          onTap: (annotationId) {
            final cluster = _annotationClusters[annotationId];
            if (cluster == null) return;
            _showDetails(
              risk: cluster['risk'] as String,
              count: cluster['count'] as int,
              members: cluster['members'] as List<dynamic>,
            );
          },
        ),
      );
    }

    await circleManager.deleteAll();
    await textManager.deleteAll();
    _annotationClusters.clear();
    if (myGeneration != _plotGeneration) return;

    final filtered = _allData.where((s) =>
        _selectedRisk == 'All' || _selectedRisk == (s['risk'] ?? 'Safe'));

    final clusters = _buildClusters(filtered);

    for (final cluster in clusters) {
      if (myGeneration != _plotGeneration) return; // a newer call took over

      final risk     = cluster['risk']  as String;
      final lat      = cluster['lat']   as double;
      final lng      = cluster['lng']   as double;
      // ignore: unused_local_variable
      final count    = cluster['count'] as int;
      final members  = cluster['members'] as List<dynamic>;
      final size     = members.length;

      final color = risk == 'Danger'
          ? const Color(0xFFFF3B30)
          : risk == 'Caution'
              ? const Color(0xFFFF9500)
              : const Color(0xFF34C759);

      // Smaller markers — Kuala Terengganu especially can have many close
      // together, so shrinking these keeps nearby points from overlapping.
      final double radius = risk == 'Danger' ? 14 : risk == 'Caution' ? 11 : 8;

      // Glow ring
      await circleManager.create(mapbox.CircleAnnotationOptions(
        geometry: mapbox.Point(
          coordinates: mapbox.Position(lng, lat),
        ),
        circleRadius: radius * 2.2,
        circleColor: color.toARGB32(),
        circleOpacity: 0.2,
        circleStrokeWidth: 0,
        circleStrokeOpacity: 0,
      ));
      if (myGeneration != _plotGeneration) return;

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
      if (myGeneration != _plotGeneration) return;

      // Report-count label — only when more than one report got grouped
      // into this cluster, so a single report doesn't show a redundant "1".
      if (size > 1) {
        await textManager.create(mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
          textField: '$size',
          textColor: Colors.white.toARGB32(),
          textSize: 12,
          textHaloColor: Colors.black.toARGB32(),
          textHaloWidth: 1,
          textOffset: [0, 0],
        ));
        if (myGeneration != _plotGeneration) return;
      }

      // Register this circle's id against its cluster data — the single
      // shared listener above looks it up here instead of getting its own
      // per-marker listener.
      _annotationClusters[core.id] = cluster;
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

      // Permission is confirmed now — (re)enable the puck here too, in case
      // it was first enabled in onMapCreated before permission existed.
      // This is what actually makes the dot move as you walk, not just the
      // camera following it.
      await _mapboxMap?.location.updateSettings(
        mapbox.LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: Colors.blue.value,
          puckBearingEnabled: true,
          puckBearing: mapbox.PuckBearing.COURSE,
          locationPuck: mapbox.LocationPuck(
            locationPuck2D: mapbox.DefaultLocationPuck2D(),
          ),
        ),
      );

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) async {
        if (!mounted) return;
        setState(() => _userPosition = pos);
        _checkGeofence(pos);
        _pushLocationToBackend(pos);

        // Waze-style: follow user, tilt 45°, rotate to heading —
        // but only while follow mode is on, so a manual pan/zoom sticks
        // until the person re-enables it via the new toggle icon.
        if (_followMode) {
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
        }
      });
    } catch (e) {
      dev.log('[Location] $e');
    }
  }

  // ── Push the user's live location to Supabase, throttled ─────────────────
  // _checkGeofence() above only compares against hotspots already loaded on
  // THIS device — it can't tell you about a brand-new report someone else
  // just submitted elsewhere. This upsert is what lets the backend trigger
  // (notify_nearby_users, run server-side) send a real push notification
  // even when this app is closed. Throttled to avoid hammering the DB on
  // every single GPS tick — once every 2 minutes, or on a big jump, is
  // plenty for a geofence check that isn't second-by-second critical.
  DateTime? _lastLocationPush;
  static const _locationPushInterval = Duration(minutes: 2);

  Future<void> _pushLocationToBackend(Position pos) async {
    final now = DateTime.now();
    if (_lastLocationPush != null &&
        now.difference(_lastLocationPush!) < _locationPushInterval) {
      return;
    }
    _lastLocationPush = now;

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      await Supabase.instance.client.from('user_locations').upsert({
        'user_id': uid,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'updated_at': now.toUtc().toIso8601String(),
      });
    } catch (e) {
      dev.log('[user_locations] $e');
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

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  // ── Detail bottom sheet — single report, or a cluster summary ─────────────
  void _showDetails({
    required String risk,
    required int count,
    required List<dynamic> members,
  }) {
    final rc = risk == 'Danger'
        ? Colors.red
        : risk == 'Caution'
            ? Colors.orange
            : Colors.green;

    final bool isCluster = members.length > 1;
    final first = members.first;
    final district = first['district'] as String? ?? 'Unknown';
    final type = first['type'] as String? ?? 'AI Hotspot';

    final int communityCount = members
        .where((m) => (m['source'] as String?) == 'user_report')
        .length;
    final int govCount = members.length - communityCount;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: isCluster ? 0.6 : 0.45,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (_, scrollCtrl) => Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: scrollCtrl,
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
                  Text(
                    isCluster ? '${members.length} reports in this area' : type,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode
                            ? Colors.white
                            : const Color(0xFF22355F)),
                  ),
                ]),
              ]),
              const SizedBox(height: 14),
              Divider(color: _isDarkMode ? Colors.white12 : Colors.grey.shade200),
              const SizedBox(height: 8),

              if (!isCluster) ...[
                _row(Icons.category_outlined,     'Report Type',           type),
                const SizedBox(height: 8),
                _row(Icons.location_on_outlined,  'Location',              district),
                const SizedBox(height: 8),
                _row(Icons.access_time_rounded,   'Date & Time',           _formatDate(first['created_at'] as String?)),
                const SizedBox(height: 8),
                _row(Icons.bar_chart_rounded,
                    'Recorded Cases (${(first['source'] as String?) == 'user_report' ? _communityYearsLabel([first]) : _govDatasetYear})',
                    '$count cases'),
                const SizedBox(height: 8),
                _row(Icons.verified_outlined,     'Source',
                    (first['source'] as String?) == 'user_report'
                        ? 'Community Report'
                        : 'K-Means Algorithm (data.gov.my)'),
                if ((first['details'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(first['details'] as String,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: _isDarkMode ? Colors.white70 : Colors.grey.shade700)),
                  ),
                ],
              ] else ...[
                // Cluster summary — one row per grouped report
                _row(Icons.location_on_outlined, 'Location', district),
                const SizedBox(height: 8),
                _row(Icons.bar_chart_rounded,
                    'Total Recorded Cases (${_clusterYearsLabel(communityCount, govCount, members)})',
                    '$count cases'),
                const SizedBox(height: 12),
                Text('Reports here',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _isDarkMode ? Colors.white : const Color(0xFF22355F))),
                const SizedBox(height: 8),
                ...members.map((m) {
                  final mRisk = m['risk'] as String? ?? 'Safe';
                  final mColor = mRisk == 'Danger'
                      ? Colors.red
                      : mRisk == 'Caution' ? Colors.orange : Colors.green;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: mColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 8, height: 8,
                            decoration: BoxDecoration(color: mColor, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(m['type'] as String? ?? 'Report',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _isDarkMode ? Colors.white : const Color(0xFF22355F))),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(_formatDate(m['created_at'] as String?),
                          style: TextStyle(
                              fontSize: 11,
                              color: _isDarkMode ? Colors.white54 : Colors.grey.shade600)),
                    ]),
                  );
                }),
              ],

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
                  Text(_riskExplanation(risk, count, communityCount, govCount, members),
                      style: TextStyle(
                          fontSize: 12,
                          color: _isDarkMode ? Colors.white70 : Colors.black87,
                          height: 1.5)),
                ]),
              ),
              const SizedBox(height: 8),
              _row(Icons.cloud_done_outlined, 'Data',
                  _isOnline ? 'data.gov.my' : 'Cached offline copy'),
            ],
          ),
        ),
      ),
    );
  }

  IconData _riskIcon(String risk) {
    if (risk == 'Danger') return Icons.warning_amber_rounded;
    if (risk == 'Caution') return Icons.info_rounded;
    return Icons.check_circle_rounded;
  }

  // Pulls the real year(s) out of community reports' own created_at
  // timestamps — e.g. "2026", or "2025–2026" if a cluster spans more than
  // one year. Unlike the fixed 2023 government dataset, this keeps moving
  // forward as new reports come in.
  String _communityYearsLabel(List<dynamic> members) {
    final years = <int>{};
    for (final m in members) {
      if ((m['source'] as String?) != 'user_report') continue;
      final raw = m['created_at'] as String?;
      if (raw == null) continue;
      try {
        years.add(DateTime.parse(raw).year);
      } catch (_) {}
    }
    if (years.isEmpty) return '${DateTime.now().year}'; // fallback: this year
    final sorted = years.toList()..sort();
    return sorted.length == 1 ? '${sorted.first}' : '${sorted.first}–${sorted.last}';
  }

  // Combines both sources' years for the header label on a cluster's
  // "Total Recorded Cases" row — e.g. "2023" (pure gov), "2026" (pure
  // community), or "2023 & 2025–2026" (mixed).
  String _clusterYearsLabel(int communityCount, int govCount, List<dynamic> members) {
    if (communityCount > 0 && govCount == 0) return _communityYearsLabel(members);
    if (govCount > 0 && communityCount == 0) return '$_govDatasetYear';
    return '$_govDatasetYear & ${_communityYearsLabel(members)}';
  }

  String _riskExplanation(String risk, int count, int communityCount, int govCount, List<dynamic> members) {
    final String provenance = _dataProvenancePhrase(count, communityCount, govCount, members);

    if (risk == 'Danger') {
      return '🔴 $provenance, placing this in the highest-risk category. '
          'Types include assault and property crime. '
          'Avoid walking alone at night and stay in well-lit public areas.';
    } else if (risk == 'Caution') {
      return '🟡 $provenance, placing this in the moderate-risk category. '
          'Crime occurs but is less frequent than Danger zones. '
          'Stay aware of your surroundings, especially in isolated areas.';
    } else {
      return '🟢 $provenance — the lowest-risk category. '
          'It is relatively safer than other areas in Terengganu. '
          'Standard safety precautions still apply.';
    }
  }

  // Only credits K-Means / data.gov.my when the cluster is actually made up
  // of that government dataset — a cluster of real community reports gets
  // its own honest description instead of a misleading "K-Means" claim,
  // and uses the report's real year instead of a hardcoded one.
  String _dataProvenancePhrase(int count, int communityCount, int govCount, List<dynamic> members) {
    if (communityCount > 0 && govCount == 0) {
      final yearLabel = _communityYearsLabel(members);
      return communityCount == 1
          ? 'This is based on 1 verified community-submitted report from $yearLabel'
          : 'This is based on $communityCount verified community-submitted reports from $yearLabel';
    }
    if (govCount > 0 && communityCount == 0) {
      return 'This district recorded $count criminal cases in $_govDatasetYear, '
          'identified by K-Means clustering on official data.gov.my crime data';
    }
    // Mixed cluster — be transparent that it blends both sources and years.
    final yearLabel = _communityYearsLabel(members);
    return 'This reflects $govCount case(s) from data.gov.my\'s $_govDatasetYear K-Means clustering '
        'combined with $communityCount verified community-submitted report(s) from $yearLabel';
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
                puckBearingEnabled: true,
                puckBearing: mapbox.PuckBearing.COURSE,
                locationPuck: mapbox.LocationPuck(
                  locationPuck2D: mapbox.DefaultLocationPuck2D(),
                ),
              ),
            );

            await _add3DBuildingsLayer(controller);
            await _plotHotspots();
          },
          onStyleLoadedListener: (_) async {
            // A style switch (dark/light toggle) reloads the ENTIRE style,
            // which wipes out any custom layer added before — including the
            // 3D buildings layer, since onMapCreated only ever fires once.
            // Re-adding it here is what keeps buildings (and the 3D look)
            // showing after every theme switch, not just on first launch.
            final map = _mapboxMap;
            if (map != null) await _add3DBuildingsLayer(map);
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
                setState(() => _followMode = true);
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
      _styleBtn(icon: Icons.dark_mode_rounded,  index: 0, tooltip: 'Dark 3D'),
      const SizedBox(height: 8),
      _styleBtn(icon: Icons.light_mode_rounded, index: 1, tooltip: 'Light 3D'),
      const SizedBox(height: 8),
      _followToggleBtn(),
    ]);
  }

  // Separate from _styleBtn since this toggles a bool, not a style index —
  // it never changes dark/light, only whether the camera keeps recentering
  // on you as you walk.
  Widget _followToggleBtn() {
    return GestureDetector(
      onTap: () async {
        final turningOn = !_followMode;
        setState(() => _followMode = turningOn);
        // Snap back to the user immediately when re-enabling, so it
        // doesn't wait for the next GPS tick to visibly do something.
        if (turningOn && _userPosition != null) {
          final pos = _userPosition!;
          await _mapboxMap?.flyTo(
            mapbox.CameraOptions(
              center: mapbox.Point(
                coordinates: mapbox.Position(pos.longitude, pos.latitude),
              ),
              zoom: 15.5,
              pitch: 45,
              bearing: pos.heading,
            ),
            mapbox.MapAnimationOptions(duration: 800),
          );
        }
      },
      child: Tooltip(
        message: _followMode ? 'Walking mode on — tap to pan freely' : 'Tap to enable walking mode',
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _followMode
                ? const Color(0xFF3B71FE)
                : (_isDarkMode ? const Color(0xFF2D2D2D) : Colors.white),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8)
            ],
          ),
          child: Icon(
            Icons.directions_walk_rounded,
            color: _followMode
                ? Colors.white
                : (_isDarkMode ? Colors.white70 : const Color(0xFF22355F)),
            size: 20,
          ),
        ),
      ),
    );
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

// ── Circle tap router — ONE listener shared across all markers ───────────────
// Mapbox's CircleAnnotationManager only keeps a single active click listener;
// this dispatches to whichever annotation id was actually tapped instead of
// each marker trying to register its own (which just overwrites the last one).

class _ClusterClickRouter extends mapbox.OnCircleAnnotationClickListener {
  final void Function(String annotationId) onTap;
  _ClusterClickRouter({required this.onTap});

  @override
  void onCircleAnnotationClick(mapbox.CircleAnnotation annotation) {
    onTap(annotation.id);
  }
}