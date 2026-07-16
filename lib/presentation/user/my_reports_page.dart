import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/user_cubit/my_reports_cubit.dart';

class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MyReportsCubit()..fetchMyReports(),
      child: const _MyReportsView(),
    );
  }
}

class _MyReportsView extends StatelessWidget {
  const _MyReportsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Reports",
          style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF3B71FE)),
            tooltip: "Refresh",
            onPressed: () =>
                context.read<MyReportsCubit>().fetchMyReports(),
          ),
        ],
      ),
      body: BlocBuilder<MyReportsCubit, MyReportsState>(
        builder: (context, state) {
          if (state is MyReportsLoading || state is MyReportsInitial) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B71FE)),
            );
          }

          if (state is MyReportsError) {
            return _ErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<MyReportsCubit>().fetchMyReports(),
            );
          }

          if (state is MyReportsLoaded) {
            if (state.reports.isEmpty) {
              return const _EmptyView();
            }
            return _ReportList(reports: state.reports);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ── Sorting / grouping helpers ──────────────────────────────────────────────

DateTime _reportDate(Map<String, dynamic> report) {
  final raw = report['created_at'];
  if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
  try {
    return DateTime.parse(raw.toString());
  } catch (_) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

List<Map<String, dynamic>> _sortedNewestFirst(List<Map<String, dynamic>> reports) {
  final sorted = List<Map<String, dynamic>>.from(reports);
  sorted.sort((a, b) => _reportDate(b).compareTo(_reportDate(a)));
  return sorted;
}

// ── Report list — grouped into Verified / Under Review / Pending sections ──

class _ReportList extends StatelessWidget {
  final List<Map<String, dynamic>> reports;
  const _ReportList({required this.reports});

  @override
  Widget build(BuildContext context) {
    final verified = _sortedNewestFirst(
        reports.where((r) => r['verified'] == true).toList());
    final dismissed = _sortedNewestFirst(reports
        .where((r) => r['verified'] != true && r['dismissed'] == true)
        .toList());
    final pending = _sortedNewestFirst(reports
        .where((r) => r['verified'] != true && r['dismissed'] != true)
        .toList());

    return RefreshIndicator(
      color: const Color(0xFF3B71FE),
      onRefresh: () => context.read<MyReportsCubit>().fetchMyReports(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _SectionHeader(
              label: "Verified", count: verified.length, color: const Color(0xFF2DBD72)),
          const SizedBox(height: 10),
          if (verified.isEmpty)
            const _SectionEmptyNote(text: "No verified reports yet")
          else
            ...verified.expand((r) => [
                  _ReportCard(report: r),
                  const SizedBox(height: 12),
                ]),

          const SizedBox(height: 20),

          _SectionHeader(
              label: "Pending", count: pending.length, color: Colors.orange),
          const SizedBox(height: 10),
          if (pending.isEmpty)
            const _SectionEmptyNote(text: "No pending reports")
          else
            ...pending.expand((r) => [
                  _ReportCard(report: r),
                  const SizedBox(height: 12),
                ]),

          const SizedBox(height: 20),

          _SectionHeader(
              label: "Dismissed", count: dismissed.length, color: Colors.grey),
          const SizedBox(height: 10),
          if (dismissed.isEmpty)
            const _SectionEmptyNote(text: "No dismissed reports")
          else
            ...dismissed.expand((r) => [
                  _ReportCard(report: r),
                  const SizedBox(height: 12),
                ]),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SectionHeader({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF22355F))),
      const SizedBox(width: 6),
      Text("($count)",
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
    ]);
  }
}

class _SectionEmptyNote extends StatelessWidget {
  final String text;
  const _SectionEmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
    );
  }
}

// ── Individual report card ────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  const _ReportCard({required this.report});

  static const Map<String, IconData> _typeIcons = {
    "Suspicious Activity": Icons.visibility_outlined,
    "Hazardous Road": Icons.warning_amber_rounded,
    "Theft/Robbery": Icons.shopping_bag_outlined,
    "Poor Lighting": Icons.nightlight_outlined,
    "Harassment": Icons.shield_outlined,
  };

  Color _statusColor(bool? verified, bool? dismissed) {
    if (verified == true) return const Color(0xFF2DBD72);
    if (dismissed == true) return Colors.grey;
    return Colors.orange;
  }

  String _statusLabel(bool? verified, bool? dismissed) {
    if (verified == true) return "Verified";
    if (dismissed == true) return "Dismissed";
    return "Pending";
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return "—";
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final months = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
      ];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year}  "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return raw.toString();
    }
  }

  // Shows the same confirmation dialog as before. Returns true only if the
  // user actually confirms — used both by the swipe gesture and can be
  // reused if a manual delete trigger is added elsewhere.
  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Report",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            "Are you sure you want to delete this report? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel",
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final type = report['type'] as String? ?? "Unknown";
    final verified = report['verified'] as bool?;
    final dismissed = report['dismissed'] as bool?;
    final dismissReason = report['dismiss_reason'] as String?;
    final details = report['details'] as String? ?? '';
    final date = _formatDate(report['created_at']);
    final icon = _typeIcons[type] ?? Icons.report_outlined;
    final statusColor = _statusColor(verified, dismissed);
    final statusLabel = _statusLabel(verified, dismissed);
    final reportId = report['id']?.toString() ?? '';

    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header row ───────────────────────────────────────────────────
          Row(children: [
            // Icon bubble
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF1FB),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF3B71FE), size: 20),
            ),
            const SizedBox(width: 12),
            // Type + date
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF22355F))),
                    const SizedBox(height: 3),
                    Text(date,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ]),
            ),
            // Status badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ),
          ]),

          if (details.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEEEFF5)),
            const SizedBox(height: 10),
            Text(
              details,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],

          if (dismissed == true && dismissReason != null && dismissReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text("Reason: $dismissReason",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ),
              ]),
            ),
          ],

          // ── Location row ─────────────────────────────────────────────────
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.location_on_outlined,
                size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(
              report['district'] as String? ?? "Unknown location",
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const Spacer(),
            // Small trash icon hint — shows this card is deletable/swipeable.
            if (verified != true)
              Icon(Icons.delete_outline_rounded, size: 17, color: Colors.grey.shade400),
          ]),
        ]),
      ),
    );

    // Verified reports are official records — keep them non-swipeable,
    // same as before where the old Delete link only showed for unverified.
    if (verified == true || reportId.isEmpty) {
      return card;
    }

    return Dismissible(
      key: ValueKey('report_$reportId'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) {
        context.read<MyReportsCubit>().deleteReport(reportId);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text("Delete",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      child: card,
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF1FB),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.article_outlined,
                size: 48, color: Color(0xFF3B71FE)),
          ),
          const SizedBox(height: 20),
          const Text("No Reports Yet",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22355F))),
          const SizedBox(height: 8),
          Text(
            "Your submitted safety reports will appear here. Tap + to make your first report.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ]),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded,
              size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text("Try Again"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B71FE),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }
}