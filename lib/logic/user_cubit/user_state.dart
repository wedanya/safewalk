import 'package:equatable/equatable.dart';
import '../../models/incident_model.dart';

abstract class UserState extends Equatable {
  const UserState();
  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserLoaded extends UserState {
  final List<IncidentModel> alerts;
  const UserLoaded(this.alerts);

  @override
  List<Object?> get props => [alerts];
}

class UserReportSuccess extends UserState {}

class UserError extends UserState {
  final String message;
  const UserError(this.message);

  @override
  List<Object?> get props => [message];
}