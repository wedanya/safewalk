import 'package:flutter/material.dart';

class ReportDetailsPage extends StatelessWidget {
  final String status;
  final String title;
  final String location;
  final String? dismissReason; // <--- ADDED
  final Function(String, String?)? onStatusUpdate; // <--- UPDATED

  const ReportDetailsPage({
    super.key,
    this.status = "Waiting",
    this.title = "Incident Report",
    this.location = "Kuala Terengganu",
    this.dismissReason, // <--- ADDED
    this.onStatusUpdate,
  });

  void _showActionBottomSheet(BuildContext context, String actionType, Color themeColor, String assetPath) {
    final TextEditingController reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                child: Image.asset(assetPath, errorBuilder: (c, e, s) => Icon(Icons.info_outline, size: 60, color: themeColor)),
              ),
              const SizedBox(height: 15),
              Text("Confirm $actionType", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Are you sure you want to $actionType this report?", style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 20),

              if (actionType == "Dismiss") ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("REASON FOR DISMISSAL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "e.g., False alarm, duplicate report...",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    if (onStatusUpdate != null) {
                      String newStatus = (actionType == "Verify") ? "Verified" : "Dismissed";
                      // Sending the reason back to the list
                      onStatusUpdate!(newStatus, actionType == "Dismiss" ? reasonController.text : null);
                    }
                    Navigator.pop(context); 
                    Navigator.pop(context); 
                  },
                  child: Text("Confirm $actionType", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0, backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.blue),
        title: const Text("Report Details", style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.map, size: 50, color: Colors.grey)),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildInfoTile("TIMESTAMP", "Oct 24, 10:45 AM"),
                  _buildInfoTile("LOCATION", location),
                  const SizedBox(height: 30),

                  // --- INTEGRATED: SHOW REASON ONLY IF DISMISSED ---
                  if (status == "Dismissed" && dismissReason != null) ...[
                    const Text("REASON FOR DISMISSAL", 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[100]!), 
                      ),
                      child: Text(
                        dismissReason!,
                        style: TextStyle(color: Colors.red[900], fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  if (status == "Waiting") ...[
                    _actionButton(context, "Verify", Colors.green, 'assets/verify_success.png'),
                    const SizedBox(height: 12),
                    _actionButton(context, "Dismiss", Colors.red, 'assets/dismiss_success.png'),
                  ] else if (status == "Verified") ...[
                    _actionButton(context, "Dismiss", Colors.red, 'assets/dismiss_success.png'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: status == "Verified" ? Colors.green[100] : (status == "Dismissed" ? Colors.red[100] : Colors.orange[100]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(status.toUpperCase(), style: TextStyle(color: status == "Verified" ? Colors.green[800] : (status == "Dismissed" ? Colors.red[800] : Colors.orange[800]), fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _actionButton(BuildContext context, String action, Color color, String asset) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: () => _showActionBottomSheet(context, action, color, asset),
        style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
        child: Text("$action Report", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}