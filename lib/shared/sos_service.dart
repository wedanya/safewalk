import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SosService {
  SosService._();
  static final SosService instance = SosService._();

  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime? _lastTriggered;
  bool _isRunning = false;

  // Shake threshold — 18.0 is a firm deliberate shake
  static const double _threshold = 18.0;
  static const Duration _cooldown = Duration(seconds: 30);

  bool get isRunning => _isRunning;

  void start(VoidCallback onTriggered) {
    if (_isRunning) return; // already listening
    _isRunning = true;
    _sub?.cancel();
    _sub = accelerometerEventStream().listen((e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      if (mag > _threshold) {
        final now = DateTime.now();
        if (_lastTriggered == null ||
            now.difference(_lastTriggered!) > _cooldown) {
          _lastTriggered = now;
          onTriggered();
        }
      }
    }, onError: (_) {
      _isRunning = false;
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _isRunning = false;
  }

  /// Fetch first emergency contact and call them.
  /// Falls back to 999 if none saved.
  Future<void> callNearestContact(BuildContext context) async {
    final db  = Supabase.instance.client;
    final uid = db.auth.currentUser?.id;
    String phone = '999';

    if (uid != null) {
      try {
        final data = await db
            .from('emergency_contacts')
            .select('phone')
            .eq('user_id', uid)
            .order('name')
            .limit(1)
            .maybeSingle();
        if (data != null && data['phone'] != null) {
          phone = (data['phone'] as String)
              .replaceAll(RegExp(r'[^0-9+]'), '');
        }
      } catch (_) {}
    }

    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}