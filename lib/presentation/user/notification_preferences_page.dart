import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  bool   _enableAlerts    = true;
  double _geofenceRadius  = 2.0;
  bool   _isLoading       = true;
  bool   _isSaving        = false;

  final _db = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  // ── Load from Supabase ────────────────────────────────────────────────────
  Future<void> _loadPrefs() async {
    setState(() => _isLoading = true);
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) { setState(() => _isLoading = false); return; }

      final data = await _db
          .from('profiles')
          .select('alert_enabled, geofence_radius_km')
          .eq('id', uid)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _enableAlerts   = (data?['alert_enabled']      as bool?)   ?? true;
          _geofenceRadius = ((data?['geofence_radius_km'] as num?)
                                ?.toDouble())                         ?? 2.0;
          _isLoading      = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Save to Supabase ──────────────────────────────────────────────────────
  Future<void> _savePrefs() async {
    setState(() => _isSaving = true);
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return;

      await _db.from('profiles').upsert({
        'id':                 uid,
        'alert_enabled':      _enableAlerts,
        'geofence_radius_km': _geofenceRadius,
        'updated_at':         DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ Preferences saved!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          "Notification preferences",
          style: TextStyle(
              color: Color(0xFF22355F),
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF22355F)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B71FE)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Alert toggle ───────────────────────────────────────────
                  const Text("Alert Settings",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22355F))),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: SwitchListTile(
                      title: const Text("Geofencing Alerts",
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF22355F))),
                      subtitle: const Text(
                          "Receive incident alerts near your location"),
                      value: _enableAlerts,
                      activeThumbColor: const Color(0xFF3B71FE),
                      activeTrackColor:
                          const Color(0xFF3B71FE).withAlpha(100),
                      onChanged: (v) => setState(() => _enableAlerts = v),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Radius slider ──────────────────────────────────────────
                  const Text("Geofence Alert Radius",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22355F))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Preferred Radius",
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF22355F),
                                    fontSize: 15)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF3B71FE).withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _geofenceRadius == 0.0
                                    ? "Exact spot"
                                    : "${_geofenceRadius.toStringAsFixed(1)} km",
                                style: const TextStyle(
                                    color: Color(0xFF3B71FE),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "You will only be alerted about incidents within this distance from your location.",
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        Slider(
                          value: _geofenceRadius,
                          min: 0.0,
                          max: 10.0,
                          divisions: 20,
                          activeColor: const Color(0xFF3B71FE),
                          inactiveColor: Colors.grey.shade200,
                          onChanged: _enableAlerts
                              ? (v) => setState(() => _geofenceRadius = v)
                              : null,
                        ),
                        // Axis labels
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Exact",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400)),
                              Text("5 km",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400)),
                              Text("10 km",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Info notice ────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          size: 15, color: Color(0xFF3B71FE)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "These preferences are saved to your account and apply across all your devices.",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 32),

                  // ── Save button ────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _savePrefs,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                          _isSaving ? "Saving..." : "Save Changes",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22355F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}