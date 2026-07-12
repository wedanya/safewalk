import 'dart:async';
import 'dart:developer' as dev;
import 'package:connectivity_plus/connectivity_plus.dart';

/// ConnectivityService — watches network state across the whole app.
/// Usage: ConnectivityService.isOnline  (sync, always up-to-date)
///        ConnectivityService.onChanged (stream of bool)
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onChanged => _controller.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription? _sub;

  /// Call once in main.dart after Supabase.initialize()
  Future<void> init() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = _isConnected(result);
    dev.log('[Network] Initial state: ${_isOnline ? "ONLINE" : "OFFLINE"}');

    _sub = Connectivity().onConnectivityChanged.listen((result) {
      final nowOnline = _isConnected(result);
      if (nowOnline != _isOnline) {
        _isOnline = nowOnline;
        _controller.add(_isOnline);
        dev.log('[Network] Changed → ${_isOnline ? "ONLINE" : "OFFLINE"}');
      }
    });
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}