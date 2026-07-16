abstract class MapState {}

class MapInitial extends MapState {}

class MapReady extends MapState {
  /// Always the Mapbox Standard style — gives us 3D buildings.
  final String styleUri;

  /// Standard style's built-in day/night look, switched at runtime
  /// instead of swapping to a whole separate style URI.
  final String lightPreset; // 'dawn' | 'day' | 'dusk' | 'night'

  final bool isDarkMode;

  MapReady({
    required this.styleUri,
    required this.lightPreset,
    required this.isDarkMode,
  });

  MapReady copyWith({String? lightPreset, bool? isDarkMode}) {
    return MapReady(
      styleUri: styleUri,
      lightPreset: lightPreset ?? this.lightPreset,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}