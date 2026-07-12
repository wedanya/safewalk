import 'package:equatable/equatable.dart';

abstract class AdminState extends Equatable {
  @override
  List<Object?> get props => [];
}

// 1. Initial State
class AdminInitial extends AdminState {}

// 2. Loading State
class AdminLoading extends AdminState {}

// 3. Data Loaded State
class AdminLoaded extends AdminState {
  final List<Map<String, dynamic>> reports;
  final String? successMessage;

  // Derived counts — computed from reports list so always in sync
int get pendingCount   => reports.where((r) => r['status'] == 'pending').length;
int get verifiedCount  => reports.where((r) => r['status'] == 'verified').length;
int get dismissedCount => reports.where((r) => r['status'] == 'dismissed').length;

  AdminLoaded(this.reports, {this.successMessage});

  @override
  List<Object?> get props => [reports, successMessage];
}

// 4. Error State
class AdminError extends AdminState {
  final String message;

  AdminError(this.message);

  @override
  List<Object?> get props => [message];
}