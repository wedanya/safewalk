import 'package:flutter/material.dart';
import 'report_details_page.dart';

class ReportListPage extends StatefulWidget {
  final int initialTabIndex;
  const ReportListPage({super.key, this.initialTabIndex = 0});

  @override
  State<ReportListPage> createState() => _ReportListPageState();
}

class _ReportListPageState extends State<ReportListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String searchQuery = "";

  // The local "database" of reports
  final List<Map<String, String>> allReports = [
    {"title": "Harassment Incident", "location": "Jalan Sultan Zainal Abidin", "time": "5 mins ago", "status": "Waiting"},
    {"title": "Street Light Outage", "location": "Kampung Cina", "time": "14 mins ago", "status": "Waiting"},
    {"title": "Suspicious Activity", "location": "Batu Burok Beach", "time": "2 hours ago", "status": "Verified"},
    {"title": "Vandalism", "location": "Pasar Payang", "time": "1 day ago", "status": "Dismissed", "reason": "Duplicate report already filed."},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, 
        vsync: this, 
        initialIndex: widget.initialTabIndex
    );
  }

  // Helper function to update the status and reason of a report
  void _updateReportStatus(String title, String newStatus, {String? reason}) {
    setState(() {
      int index = allReports.indexWhere((report) => report['title'] == title);
      if (index != -1) {
        allReports[index]['status'] = newStatus;
        if (reason != null && reason.isNotEmpty) {
          allReports[index]['reason'] = reason;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("SafeWalk Admin", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: "Waiting"),
            Tab(text: "Verified"),
            Tab(text: "Dismissed"),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Search by incident or location...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFilteredList("Waiting"),
                _buildFilteredList("Verified"),
                _buildFilteredList("Dismissed"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredList(String status) {
    final filteredList = allReports.where((report) {
      final matchesStatus = report['status'] == status;
      final matchesSearch = report['title']!.toLowerCase().contains(searchQuery) || 
                            report['location']!.toLowerCase().contains(searchQuery);
      return matchesStatus && matchesSearch;
    }).toList();

    // Empty state UI
    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No $status reports found.", 
              style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    Color cardColor;
    if (status == "Waiting") {
      cardColor = Colors.orange[50]!;
    } else if (status == "Verified") {
      cardColor = Colors.green[50]!;
    } else {
      cardColor = Colors.grey[200]!;
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final item = filteredList[index];
        return _reportCard(
          context, 
          item['title']!, 
          "${item['time']} • ${item['location']}", 
          cardColor, 
          status,
        );
      },
    );
  }

  Widget _reportCard(BuildContext context, String title, String sub, Color backgroundColor, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        // ignore: deprecated_member_use
        side: BorderSide(color: backgroundColor.withOpacity(0.5), width: 1),
      ),
      color: backgroundColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          // Find existing reason safely
          final reportData = allReports.firstWhere(
            (r) => r['title'] == title,
            orElse: () => {},
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportDetailsPage(
                status: status,
                title: title,
                location: sub,
                dismissReason: reportData['reason'], // Passing the saved reason
                onStatusUpdate: (newStatus, reason) {
                  _updateReportStatus(title, newStatus, reason: reason);
                },
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
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(sub, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    const SizedBox(height: 10),
                    const Text("View details >", 
                      style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                width: 45, 
                height: 45, 
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(0.8), 
                  borderRadius: BorderRadius.circular(10)
                ),
                child: const Icon(Icons.location_on, color: Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}