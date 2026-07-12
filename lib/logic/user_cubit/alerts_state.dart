abstract class AlertsState {}
class AlertsInitial extends AlertsState {}
class AlertsLoading extends AlertsState {}
class AlertsLoaded extends AlertsState {
  final List<Map<String, dynamic>> hotspots;
  final bool fromCache;
  final String lastUpdated;
  AlertsLoaded(this.hotspots, {this.fromCache = false, this.lastUpdated = ''});
}
class AlertsError extends AlertsState {
  final String message;
  final List<Map<String, dynamic>> cachedHotspots;
  final String lastUpdated;
  AlertsError(this.message, {this.cachedHotspots = const [], this.lastUpdated = ''});
}