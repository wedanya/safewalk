abstract class MyReportsState {}
class MyReportsInitial extends MyReportsState {}
class MyReportsLoading extends MyReportsState {}
class MyReportsLoaded extends MyReportsState {
  final List<Map<String, dynamic>> reports;
  MyReportsLoaded(this.reports);
}
class MyReportsError extends MyReportsState {
  final String message;
  MyReportsError(this.message);
}