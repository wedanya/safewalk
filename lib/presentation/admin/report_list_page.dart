import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/admin_cubit/admin_logic.dart';
import 'report_details_page.dart';

class ReportListPage extends StatefulWidget {
  final int initialTabIndex;
  const ReportListPage({super.key, this.initialTabIndex = 0});

  @override
  State<ReportListPage> createState() => _ReportListPageState();
}

class _ReportListPageState extends State<ReportListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocListener<AdminCubit, AdminState>(
        // Show snackbar on error without rebuilding the whole page
        listenWhen: (_, curr) => curr is AdminError,
        listener: (context, state) {
          if (state is AdminError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ));
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              // ── Refresh button — compact, right-aligned, no title ──────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    BlocBuilder<AdminCubit, AdminState>(
                      builder: (context, state) {
                        if (state is AdminLoading) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        return IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.blue),
                          onPressed: () =>
                              context.read<AdminCubit>().fetchPendingReports(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Tab bar ──────────────────────────────────────────────
              TabBar(
                controller: _tabController,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                // Show live counts on each tab
                tabs: [
                  BlocBuilder<AdminCubit, AdminState>(
                    builder: (context, state) {
                      final n = state is AdminLoaded ? state.pendingCount : 0;
                      return Tab(text: "Waiting${n > 0 ? ' ($n)' : ''}");
                    },
                  ),
                  BlocBuilder<AdminCubit, AdminState>(
                    builder: (context, state) {
                      final n = state is AdminLoaded ? state.verifiedCount : 0;
                      return Tab(text: "Verified${n > 0 ? ' ($n)' : ''}");
                    },
                  ),
                  BlocBuilder<AdminCubit, AdminState>(
                    builder: (context, state) {
                      final n = state is AdminLoaded ? state.dismissedCount : 0;
                      return Tab(text: "Dismissed${n > 0 ? ' ($n)' : ''}");
                    },
                  ),
                ],
              ),

              Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (value) =>
                    setState(() => searchQuery = value.toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Search by incident or location...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<AdminCubit, AdminState>(
                builder: (context, state) {
                  if (state is AdminLoading) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.blue));
                  }
                  if (state is AdminError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              size: 60, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(state.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context
                                .read<AdminCubit>()
                                .fetchPendingReports(),
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    );
                  }

                  // Both AdminInitial and AdminLoaded fall through here
                  final reports =
                      state is AdminLoaded ? state.reports : <Map<String, dynamic>>[];

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFilteredList(context, reports, 'pending'),
                      _buildFilteredList(context, reports, 'verified'),
                      _buildFilteredList(context, reports, 'dismissed'),
                    ],
                  );
                },
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredList(
      BuildContext context, List<Map<String, dynamic>> reports, String status) {
    final filtered = reports.where((r) {
      // Support both 'status' field and the old boolean 'verified' field
      final reportStatus = r['status']?.toString().toLowerCase() ??
          (r['verified'] == true ? 'verified' : 'pending');
      final matchesStatus = reportStatus == status;
      final title = (r['title'] ?? r['type'] ?? '').toString().toLowerCase();
      final location = (r['location'] ?? r['district'] ?? '').toString().toLowerCase();
      final matchesSearch =
          title.contains(searchQuery) || location.contains(searchQuery);
      return matchesStatus && matchesSearch;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No $status reports found.",
                style: TextStyle(
                    color: Colors.grey[500], fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    final cardColor = status == 'pending'
        ? Colors.orange[50]!
        : status == 'verified'
            ? Colors.green[50]!
            : Colors.grey[200]!;

    return RefreshIndicator(
      onRefresh: () => context.read<AdminCubit>().fetchPendingReports(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          final title =
              (item['title'] ?? item['type'] ?? 'Incident').toString();
          final location =
              (item['location'] ?? item['district'] ?? 'Unknown').toString();
          final time = (item['time'] ?? item['created_at'] ?? '').toString();
          final sub = [if (time.isNotEmpty) time, location]
              .join(' • ');

          return _reportCard(
            context,
            item,
            title,
            sub,
            cardColor,
            status,
          );
        },
      ),
    );
  }

  Widget _reportCard(BuildContext context, Map<String, dynamic> item,
      String title, String sub, Color backgroundColor, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
            // ignore: deprecated_member_use
            color: backgroundColor.withOpacity(0.5),
            width: 1),
      ),
      color: backgroundColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          final cubit = context.read<AdminCubit>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: cubit,
                child: ReportDetailsPage(
                  reportId: item['id']?.toString() ?? '',
                  status: status,
                  title: title,
                  location: (item['location'] ?? item['district'] ?? '').toString(),
                  dismissReason: item['dismiss_reason']?.toString(),
                  details: item['details']?.toString(),
                  lat: (item['lat'] as num?)?.toDouble(),
                  lng: (item['lng'] as num?)?.toDouble(),
                  imageUrl: item['image_url']?.toString(),
                  timestamp: (item['created_at'] ?? item['time'])?.toString(),
                ),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(sub,
                        style:
                            TextStyle(color: Colors.grey[700], fontSize: 13)),
                    const SizedBox(height: 10),
                    const Text("View details >",
                        style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
              ),
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.location_on, color: Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}