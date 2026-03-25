import 'package:equatable/equatable.dart';

abstract class AdminState extends Equatable {
  @override
  List<Object?> get props => [];
}

// 1. Initial State
class AdminInitial extends AdminState {}

// 2. Loading State (When fetching data or running K-Means)
class AdminLoading extends AdminState {}

// 3. Data Loaded State (Contains the list of incident reports)
class AdminLoaded extends AdminState {
  final List<Map<String, dynamic>> reports;
  final String? successMessage;

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