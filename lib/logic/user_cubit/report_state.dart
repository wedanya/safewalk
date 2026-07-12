abstract class ReportState {}

class ReportInitial extends ReportState {}

class ReportFetchingLocation extends ReportState {}

class ReportLocationReady extends ReportState {
  final String selectedType;
  final String locationLabel;
  final double? lat;
  final double? lng;
  final String? district;
  final bool isOnline;
  final int pendingCount;
  final int lastSyncedCount;

  ReportLocationReady({
    this.selectedType = '',
    this.locationLabel = 'Fetching location...',
    this.lat,
    this.lng,
    this.district,
    this.isOnline = true,
    this.pendingCount = 0,
    this.lastSyncedCount = 0,
  });

  ReportLocationReady copyWith({
    String? selectedType,
    String? locationLabel,
    double? lat,
    double? lng,
    String? district,
    bool? isOnline,
    int? pendingCount,
    int? lastSyncedCount,
  }) {
    return ReportLocationReady(
      selectedType:   selectedType   ?? this.selectedType,
      locationLabel:  locationLabel  ?? this.locationLabel,
      lat:            lat            ?? this.lat,
      lng:            lng            ?? this.lng,
      district:       district       ?? this.district,
      isOnline:       isOnline       ?? this.isOnline,
      pendingCount:   pendingCount   ?? this.pendingCount,
      lastSyncedCount: lastSyncedCount ?? this.lastSyncedCount,
    );
  }
}

class ReportSubmitting extends ReportState {
  final ReportLocationReady locationState;
  ReportSubmitting(this.locationState);
}

class ReportSubmitSuccess extends ReportState {
  final bool savedOffline;
  ReportSubmitSuccess({this.savedOffline = false});
}

class ReportSubmitFailure extends ReportState {
  final String message;
  final bool savedOffline;
  ReportSubmitFailure(this.message, {this.savedOffline = false});
}