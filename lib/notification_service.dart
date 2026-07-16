import 'package:flutter/foundation.dart';
// ignore: unnecessary_import
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      // Capped with a timeout — if the permission dialog can't render yet
      // for any reason, this must fail loudly instead of hanging forever.
      await _fcm
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(const Duration(seconds: 10));

      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      // foreground: FCM doesn't auto-show a banner, so show one ourselves
      FirebaseMessaging.onMessage.listen((msg) {
        final n = msg.notification;
        if (n == null) return;
        _local.show(
          n.hashCode,
          n.title,
          n.body,
          const NotificationDetails(
            android: AndroidNotificationDetails('alerts', 'Alerts',
                importance: Importance.high, priority: Priority.high),
            iOS: DarwinNotificationDetails(),
          ),
        );
      });

      await _syncToken();
      _fcm.onTokenRefresh.listen((_) => _syncToken());
    } catch (e) {
      // Never let a notification-setup failure take down app startup —
      // log it and move on. Push just won't work until this is fixed,
      // but the app itself keeps functioning.
      debugPrint('[NotificationService.init] failed: $e');
    }
  }

  static Future<void> _syncToken() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final token = await _fcm.getToken().timeout(const Duration(seconds: 10));
      if (token == null) return;

      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': uid,
        'token': token,
        'platform':
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
    } catch (e) {
      debugPrint('[NotificationService._syncToken] failed: $e');
    }
  }
}