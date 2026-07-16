import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── States ────────────────────────────────────────────────────────────────────

abstract class FeedState {}
class FeedInitial extends FeedState {}
class FeedLoading extends FeedState {}
class FeedLoaded extends FeedState {
  final List<Map<String, dynamic>> reports;
  FeedLoaded(this.reports);
}
class FeedError extends FeedState {
  final String message;
  FeedError(this.message);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class FeedCubit extends Cubit<FeedState> {
  FeedCubit() : super(FeedInitial());

  final _db = Supabase.instance.client;

  Future<void> fetchFeed() async {
    emit(FeedLoading());
    try {
      // Fetch all verified user reports (community reports only)
      final data = await _db
          .from('hotspots')
          .select()
          .eq('verified', true)
          .eq('source', 'user_report')
          .order('created_at', ascending: false);

      emit(FeedLoaded(List<Map<String, dynamic>>.from(data)));
    } catch (e) {
      emit(FeedError('Could not load community feed: $e'));
    }
  }

  Future<List<Map<String, dynamic>>> fetchComments(String reportId) async {
    try {
      final data = await _db
          .from('report_comments')
          .select()
          .eq('report_id', reportId)
          .order('created_at');
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  Future<bool> addComment({
    required String reportId,
    required String body,
  }) async {
    try {
      final user = _db.auth.currentUser;
      if (user == null) return false;

      // Fetch username + avatar from profiles so comments always match
      // whatever the person set on their Profile page.
      final profile = await _db
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      final username  = (profile?['username'] as String?) ?? 'Anonymous';
      final avatarUrl = profile?['avatar_url'] as String?;

      await _db.from('report_comments').insert({
        'report_id':  reportId,
        'user_id':    user.id,
        'username':   username,
        'avatar_url': avatarUrl,
        'body':       body.trim(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      final deleted = await _db
          .from('report_comments')
          .delete()
          .eq('id', commentId)
          .select();
      return (deleted as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}