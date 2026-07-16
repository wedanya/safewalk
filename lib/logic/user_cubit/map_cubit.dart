import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'map_state.dart';

class MapCubit extends Cubit<MapState> {
  MapCubit() : super(MapInitial()) {
    _applyPresetForCurrentTime();
    // Re-check every minute so it flips automatically without needing
    // to restart the app right at the 7pm/7am boundary.
    _clockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _applyPresetForCurrentTime(),
    );
  }

  Timer? _clockTimer;

  // The Standard style is what gives you 3D buildings — this one style
  // handles both day and night via lightPreset, so there's no separate
  // dark/light style URI to swap between.
  static const String standardStyleUri = 'mapbox://styles/mapbox/standard';

  bool _isNightTime() {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 7; // 7pm–7am = night
  }

  void _applyPresetForCurrentTime() {
    final isDark = _isNightTime();
    final preset = isDark ? 'night' : 'day';

    final current = state;
    if (current is MapReady && current.lightPreset == preset) return; // no change

    if (current is MapReady) {
      emit(current.copyWith(lightPreset: preset, isDarkMode: isDark));
    } else {
      emit(MapReady(
        styleUri: standardStyleUri,
        lightPreset: preset,
        isDarkMode: isDark,
      ));
    }
  }

  /// Optional manual override — e.g. a toggle switch in the UI that lets
  /// someone force dark/light regardless of the clock.
  void setManualPreset(bool dark) {
    final current = state;
    if (current is! MapReady) return;
    emit(current.copyWith(lightPreset: dark ? 'night' : 'day', isDarkMode: dark));
  }

  @override
  Future<void> close() {
    _clockTimer?.cancel();
    return super.close();
  }
}