import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../logic/user_cubit/feed_cubit.dart';

class CommunityFeedPage extends StatelessWidget {
  const CommunityFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FeedCubit()..fetchFeed(),
      child: const _FeedView(),
    );
  }
}

class _FeedView extends StatelessWidget {
  const _FeedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F8),
        elevation: 0,
        title: const Text('Community Reports',
            style: TextStyle(
                color: Color(0xFF22355F),
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF3B71FE)),
            onPressed: () => context.read<FeedCubit>().fetchFeed(),
          ),
        ],
      ),
      body: BlocBuilder<FeedCubit, FeedState>(
        builder: (context, state) {
          if (state is FeedLoading || state is FeedInitial) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF3B71FE)));
          }
          if (state is FeedError) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                Text(state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => context.read<FeedCubit>().fetchFeed(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B71FE)),
                  child: const Text('Retry',
                      style: TextStyle(color: Colors.white)),
                ),
              ]),
            );
          }
          if (state is FeedLoaded) {
            if (state.reports.isEmpty) {
              return const Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.people_outline, size: 56, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No community reports yet',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22355F))),
                  SizedBox(height: 8),
                  Text('Be the first to submit a verified report!',
                      style: TextStyle(color: Colors.grey)),
                ]),
              );
            }
            return RefreshIndicator(
              color: const Color(0xFF3B71FE),
              onRefresh: () => context.read<FeedCubit>().fetchFeed(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                itemCount: state.reports.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) =>
                    _FeedCard(report: state.reports[i]),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final Map<String, dynamic> report;
  const _FeedCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final type     = report['type']     as String? ?? 'Incident';
    final district = report['district'] as String? ?? 'Unknown';
    final details  = report['details']  as String? ?? '';
    final id       = report['id']?.toString() ?? '';

    return GestureDetector(
      onTap: () => _openComments(context, id, type, district, details),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF1FB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFF3B71FE), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(type,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF22355F))),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ]),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(details,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.location_on_outlined,
                size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(district,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500)),
            const Spacer(),
            const Icon(Icons.comment_outlined,
                size: 14, color: Color(0xFF3B71FE)),
            const SizedBox(width: 4),
            const Text('Tap to comment',
                style: TextStyle(
                    fontSize: 11, color: Color(0xFF3B71FE))),
          ]),
        ]),
      ),
    );
  }

  void _openComments(BuildContext context, String id, String type,
      String district, String details) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<FeedCubit>(),
          child: _CommentsPage(
            reportId: id,
            title: type,
            district: district,
            details: details,
          ),
        ),
      ),
    );
  }
}

class _CommentsPage extends StatefulWidget {
  final String reportId;
  final String title;
  final String district;
  final String details;
  const _CommentsPage({
    required this.reportId,
    required this.title,
    required this.district,
    required this.details,
  });

  @override
  State<_CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<_CommentsPage> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final c = await context.read<FeedCubit>().fetchComments(widget.reportId);
    if (mounted) setState(() { _comments = c; _loading = false; });
  }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    final ok = await context.read<FeedCubit>().addComment(
      reportId: widget.reportId, body: text,
    );
    if (ok) { _ctrl.clear(); await _load(); }
    if (mounted) setState(() => _posting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F8),
        elevation: 0,
        title: Text(widget.title,
            style: const TextStyle(
                color: Color(0xFF22355F),
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
        leading: const BackButton(color: Color(0xFF22355F)),
      ),
      body: Column(children: [
        // Report summary card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.location_on, color: Color(0xFF3B71FE), size: 16),
              const SizedBox(width: 6),
              Text(widget.district,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22355F))),
            ]),
            if (widget.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(widget.details,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600)),
            ],
          ]),
        ),

        // Comments list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF3B71FE)))
              : _comments.isEmpty
                  ? const Center(
                      child: Text('No comments yet. Be the first!',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _comments.length,
                      itemBuilder: (_, i) => _CommentTile(
                        comment: _comments[i],
                        onDelete: () async {
                          await context
                              .read<FeedCubit>()
                              .deleteComment(_comments[i]['id'].toString());
                          await _load();
                        },
                      ),
                    ),
        ),

        // Comment input
        Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          color: Colors.white,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLength: 300,
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFF0F2F8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _posting ? null : _post,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF3B71FE),
                  shape: BoxShape.circle,
                ),
                child: _posting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback onDelete;
  const _CommentTile({required this.comment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final isOwn = comment['user_id']?.toString() == uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xFFEEF1FB),
          child: Icon(Icons.person, color: Color(0xFF3B71FE), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(comment['username'] as String? ?? 'User',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF22355F))),
            const SizedBox(height: 4),
            Text(comment['body'] as String? ?? '',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade700)),
          ]),
        ),
        if (isOwn)
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 16, color: Colors.grey),
          ),
      ]),
    );
  }
}