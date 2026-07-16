import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../logic/user_cubit/feed_cubit.dart';

// ── Alert detail page — dedicated full screen, X/Twitter-style ───────────────

class AlertDetailPage extends StatelessWidget {
  final Map<String, dynamic> spot;
  const AlertDetailPage({super.key, required this.spot});

  String _fmt(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month-1]} ${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return raw; }
  }

  String _tempoh(String? verifiedAt) {
    if (verifiedAt == null) return '—';
    try {
      final diff = DateTime.now().difference(DateTime.parse(verifiedAt));
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24)   return '${diff.inHours} hours ago';
      if (diff.inDays < 30)    return '${diff.inDays} days ago';
      return '${(diff.inDays / 30).floor()} months ago';
    } catch (_) { return '—'; }
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: Colors.grey),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      Expanded(child: Text(value, style: const TextStyle(
          color: Color(0xFF22355F), fontWeight: FontWeight.w600, fontSize: 12))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final String district    = spot['district']   as String? ?? 'Unknown';
    final String type        = spot['type']       as String? ?? 'Hotspot';
    final String risk        = spot['risk']       as String? ?? 'Safe';
    final int    count       = (spot['crime_count'] as num?)?.toInt() ?? 0;
    final String? reportedAt = spot['created_at'] as String?;
    final String? verifiedAt = spot['updated_at'] as String? ?? spot['created_at'] as String?;
    final String? imageUrl   = spot['image_url']  as String?;
    final String? notes      = spot['details']    as String?;
    final int?    reportCount = (spot['report_count'] as num?)?.toInt();
    final String  id         = spot['id']?.toString() ?? '';

    final Color rc = risk == 'Danger' ? Colors.red : (risk == 'Caution' ? Colors.orange : Colors.green);

    return BlocProvider(
      create: (_) => FeedCubit(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: const Color(0xFF22355F),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Alert Details',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF22355F))),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
          // Risk badge
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: rc.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(
                risk == 'Danger' ? 'HIGH RISK' : risk == 'Caution' ? 'CAUTION' : 'SAFE ZONE',
                style: TextStyle(color: rc, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const Spacer(),
            Text('Verified  ${_tempoh(verifiedAt)}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ]),
          const SizedBox(height: 12),

          // Title
          Text(district, style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF22355F))),
          const SizedBox(height: 4),
          Text(type, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 12),

          // Details
          _detailRow(Icons.category_outlined,       'Report Type',          type),
          _detailRow(Icons.location_on_outlined,    'Location',             district),
          _detailRow(Icons.calendar_today_outlined, 'Date Reported',        _fmt(reportedAt)),
          _detailRow(Icons.verified_outlined,       'Date & Time Verified', _fmt(verifiedAt)),
          _detailRow(Icons.bar_chart_rounded,       'Recorded Cases (2023)','$count cases'),
          if (reportCount != null && reportCount > 1)
            _detailRow(Icons.groups_outlined, 'Combined From', '$reportCount community reports'),
          _detailRow(Icons.info_outline,            'Risk Explanation',
            risk == 'Danger'
              ? 'High crime area (300+ cases). Avoid isolated areas at night.'
              : risk == 'Caution'
                ? 'Moderate crime (100–299 cases). Stay alert in public.'
                : 'Low crime area (<100 cases). Relatively safe.'),

          // Photo
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Photo Evidence',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                    color: Color(0xFF22355F))),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(imageUrl, height: 200, width: double.infinity,
                  fit: BoxFit.cover,
                  // ignore: unnecessary_underscores
                  errorBuilder: (_, __, ___) => Container(height: 80,
                      color: Colors.grey.shade100,
                      child: const Center(child: Icon(Icons.broken_image_outlined,
                          color: Colors.grey)))),
            ),
          ],

          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Notes', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF22355F))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC), borderRadius: BorderRadius.circular(12)),
              child: Text(notes,
                  style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey.shade700)),
            ),
          ],

          // Comment section
          if (id.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 12),
            _CommentSection(reportId: id),
          ],
        ]),
      ),
    );
  }
}

// ── Avatar preset colors (mirrors profile_page / signup_page) ────────────────
Color _presetBg(String? key) {
  switch (key) {
    case 'avatar_blue':   return const Color(0xFFE8F0FE);
    case 'avatar_amber':  return const Color(0xFFFFF3E0);
    case 'avatar_teal':   return const Color(0xFFE0F2F1);
    case 'avatar_purple': return const Color(0xFFF3E5F5);
    case 'avatar_rose':   return const Color(0xFFFFEBEE);
    default:              return const Color(0xFFEEF1FB);
  }
}

Color _presetIcon(String? key) {
  switch (key) {
    case 'avatar_blue':   return const Color(0xFF3B71FE);
    case 'avatar_amber':  return const Color(0xFFFF9800);
    case 'avatar_teal':   return const Color(0xFF009688);
    case 'avatar_purple': return const Color(0xFF9C27B0);
    case 'avatar_rose':   return const Color(0xFFE91E63);
    default:              return const Color(0xFF3B71FE);
  }
}

/// Renders the poster's real avatar (photo or preset), falling back to a
/// generic icon only if nothing was ever set — kept in sync with whatever
/// they picked on their Profile page.
Widget _commentAvatar(String? avatarUrl) {
  final bool isNetworkImage = avatarUrl != null && avatarUrl.startsWith('http');
  return CircleAvatar(
    radius: 14,
    backgroundColor: _presetBg(isNetworkImage ? null : avatarUrl),
    backgroundImage: isNetworkImage ? NetworkImage(avatarUrl) : null,
    child: !isNetworkImage
        ? Icon(Icons.person, color: _presetIcon(avatarUrl), size: 16)
        : null,
  );
}

// ── Comment section widget ────────────────────────────────────────────────────

class _CommentSection extends StatefulWidget {
  final String reportId;
  const _CommentSection({required this.reportId});
  @override
  State<_CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<_CommentSection> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _posting = false;
  String? _deletingId;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<FeedCubit>().fetchComments(widget.reportId);
      if (mounted) {
        setState(() { _comments = data; _loading = false; });
      }
    } catch (_) {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) { return; }
    setState(() => _posting = true);
    try {
      final ok = await context.read<FeedCubit>().addComment(
        reportId: widget.reportId,
        body: text,
      );
      if (ok) {
        _ctrl.clear();
        await _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post comment. Please try again.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post comment. Please try again.')),
        );
      }
    }
    if (mounted) { setState(() => _posting = false); }
  }

  Future<void> _delete(String commentId) async {
    setState(() => _deletingId = commentId);

    // Optimistically remove it from the UI immediately.
    final removed = _comments.firstWhere((c) => c['id'].toString() == commentId);
    setState(() => _comments.removeWhere((c) => c['id'].toString() == commentId));

    final ok = await context.read<FeedCubit>().deleteComment(commentId);

    if (!ok && mounted) {
      // Put it back if the delete actually failed (e.g. blocked by RLS).
      setState(() => _comments.insert(0, removed));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete comment — check permissions.')),
      );
    }

    if (mounted) setState(() => _deletingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Community Comments',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF22355F))),
      const SizedBox(height: 12),

      if (_loading)
        const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B71FE)))
      else if (_comments.isEmpty)
        const Text('No comments yet. Be the first!',
            style: TextStyle(color: Colors.grey, fontSize: 12))
      else
        ..._comments.map((c) {
          final commentId = c['id'].toString();
          final isOwn = c['user_id']?.toString() == uid;
          final isDeleting = _deletingId == commentId;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFF7F8FC), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _commentAvatar(c['avatar_url'] as String?),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['username'] as String? ?? 'User',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                        color: Color(0xFF22355F))),
                const SizedBox(height: 4),
                Text(c['body'] as String? ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ])),
              if (isOwn)
                GestureDetector(
                  onTap: isDeleting ? null : () => _delete(commentId),
                  child: isDeleting
                      ? const SizedBox(
                          width: 15, height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
                      : const Icon(Icons.close, size: 15, color: Colors.grey),
                ),
            ]),
          );
        }),

      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            maxLength: 300,
            maxLines: 1,
            decoration: InputDecoration(
              hintText: 'Add a comment...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF7F8FC),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _posting ? null : _post,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: const BoxDecoration(color: Color(0xFF3B71FE), shape: BoxShape.circle),
            child: _posting
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ),
      ]),
    ]);
  }
}