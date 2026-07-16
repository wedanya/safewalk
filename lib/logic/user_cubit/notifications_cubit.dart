// notifications_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsCubit extends Cubit<List<Map<String, dynamic>>> {
  NotificationsCubit() : super([]) {
    _subscribe();
  }
  final _db = Supabase.instance.client;

  Future<void> _subscribe() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;

    final initial = await _db
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    emit(List<Map<String, dynamic>>.from(initial));

    _db.channel('notifications:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (payload) => emit([payload.newRecord, ...state]),
        )
        .subscribe();
  }

  int get unreadCount => state.where((n) => n['is_read'] == false).length;

  Future<void> markRead(String id) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', id);
    emit(state.map((n) => n['id'] == id ? {...n, 'is_read': true} : n).toList());
  }
}