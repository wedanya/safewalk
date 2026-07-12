import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../logic/admin_cubit/admin_logic.dart';

class ReportDetailsPage extends StatefulWidget {
  final String reportId;
  final String status;
  final String title;
  final String location;
  final String? dismissReason;
  final String? details;
  final double? lat;
  final double? lng;
  final String? imageUrl;
  final String? timestamp;

  const ReportDetailsPage({
    super.key,
    required this.reportId,
    this.status = 'pending',
    this.title = 'Incident Report',
    this.location = 'Kuala Terengganu',
    this.dismissReason,
    this.details,
    this.lat,
    this.lng,
    this.imageUrl,
    this.timestamp,
  });

  @override
  State<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends State<ReportDetailsPage> {
  bool _kMeansPromptShown = false;

  // ── Format timestamp ──────────────────────────────────────────────────────
  String _formatTimestamp(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  // ── K-Means prompt after verify ───────────────────────────────────────────
  void _showKMeansDialog(BuildContext ctx) {
    if (_kMeansPromptShown) return;
    _kMeansPromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Report Verified!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ]),
          content: const Text(
            'Would you like to re-run K-Means clustering now to update the danger map with this new verified data?',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<AdminCubit>().runKMeansClustering();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Running K-Means clustering...'),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 3),
                ));
              },
              icon: const Icon(Icons.radar_rounded, size: 18),
              label: const Text('Run K-Means'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Action bottom sheet ───────────────────────────────────────────────────
  void _showActionBottomSheet(BuildContext context, String actionType, Color themeColor) {
    final reasonController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          left: 24, right: 24, top: 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 50, height: 5,
            decoration: BoxDecoration(
                color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(
              actionType == 'Verify'
                  ? Icons.check_circle_outline_rounded
                  : Icons.cancel_outlined,
              color: themeColor, size: 40,
            ),
          ),
          const SizedBox(height: 15),
          Text('Confirm $actionType',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Are you sure you want to $actionType this report?',
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 20),
          if (actionType == 'Dismiss') ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('REASON FOR DISMISSAL',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g., False alarm, duplicate report...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
          ],
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
              onPressed: () {
                final cubit = context.read<AdminCubit>();
                if (actionType == 'Verify') {
                  cubit.verifyIncident(widget.reportId);
                } else {
                  cubit.dismissIncident(
                    widget.reportId,
                    reason: reasonController.text.trim().isEmpty
                        ? null
                        : reasonController.text.trim(),
                  );
                }
                Navigator.pop(sheetCtx);
                Navigator.pop(context);
              },
              child: Text('Confirm $actionType',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
              onPressed: () => Navigator.pop(sheetCtx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── Full screen image viewer ──────────────────────────────────────────────
  void _showFullImage(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: const BackButton(color: Colors.white),
            title: const Text('Photo Evidence',
                style: TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  // ── Status badge ──────────────────────────────────────────────────────────
  Widget _statusBadge(String s) {
    final color = s == 'verified'
        ? Colors.green
        : s == 'dismissed'
            ? Colors.red
            : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Text(s.toUpperCase(),
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(fontSize: 16, color: Color(0xFF22355F))),
      const SizedBox(height: 15),
    ]);
  }

  Widget _actionButton(BuildContext context, String action, Color color) {
    return SizedBox(
      width: double.infinity, height: 55,
      child: ElevatedButton(
        onPressed: () => _showActionBottomSheet(context, action, color),
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0),
        child: Text('$action Report',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasCoords = widget.lat != null && widget.lng != null;
    final point = hasCoords
        ? LatLng(widget.lat!, widget.lng!)
        : const LatLng(5.3302, 103.1148);

    return BlocListener<AdminCubit, AdminState>(
      listenWhen: (_, curr) =>
          curr is AdminLoaded && curr.successMessage == 'kMeansPrompt',
      listener: (ctx, _) => _showKMeansDialog(ctx),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: const BackButton(color: Colors.blue),
          title: const Text('Report Details',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold)),
          actions: [
            BlocBuilder<AdminCubit, AdminState>(
              builder: (context, state) {
                String liveStatus = widget.status;
                if (state is AdminLoaded) {
                  final match = state.reports.firstWhere(
                    (r) => r['id']?.toString() == widget.reportId,
                    orElse: () => {},
                  );
                  if (match.isNotEmpty) {
                    liveStatus = match['status']?.toString() ??
                        (match['verified'] == true ? 'verified' : 'pending');
                  }
                }
                return Padding(
                  padding:
                      const EdgeInsets.only(right: 12, top: 12, bottom: 12),
                  child: _statusBadge(liveStatus),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Real map with pin ─────────────────────────────────────────
            SizedBox(
              height: 220,
              child: Stack(children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: hasCoords ? 15.0 : 10.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.safewalk.app',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: point,
                        width: 48, height: 48,
                        child: const Icon(Icons.location_on_rounded,
                            color: Colors.red,
                            size: 48,
                            shadows: [Shadow(
                                color: Colors.black38,
                                blurRadius: 8,
                                offset: Offset(0, 2))]),
                      ),
                    ]),
                  ],
                ),
                if (hasCoords)
                  Positioned(
                    bottom: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.lat!.toStringAsFixed(5)}, ${widget.lng!.toStringAsFixed(5)}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                if (!hasCoords)
                  Positioned(
                    bottom: 12, left: 0, right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                            'No exact coordinates — showing district area',
                            style: TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                Text(widget.title,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF22355F))),
                const SizedBox(height: 20),

                _buildInfoTile('TIMESTAMP', _formatTimestamp(widget.timestamp)),
                _buildInfoTile('LOCATION', widget.location),
                if (widget.details != null && widget.details!.isNotEmpty)
                  _buildInfoTile('DETAILS', widget.details!),
                const SizedBox(height: 10),

                // ── Submitted image ───────────────────────────────────────
                if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ...[
                  const Text('SUBMITTED IMAGE',
                      style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: GestureDetector(
                      onTap: () =>
                          _showFullImage(context, widget.imageUrl!),
                      child: Stack(children: [
                        Image.network(
                          widget.imageUrl!,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : Container(
                                      height: 220,
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                          child: CircularProgressIndicator(
                                              color: Color(0xFF3B71FE))),
                                    ),
                          errorBuilder: (_, _, _) => Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.broken_image_outlined,
                                        color: Colors.grey, size: 32),
                                    SizedBox(height: 8),
                                    Text('Image unavailable',
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12)),
                                  ]),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10, right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.zoom_out_map_rounded,
                                      color: Colors.white, size: 13),
                                  SizedBox(width: 4),
                                  Text('Tap to expand',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11)),
                                ]),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Row(children: [
                      Icon(Icons.image_not_supported_outlined,
                          color: Colors.grey, size: 18),
                      SizedBox(width: 10),
                      Text('No image submitted with this report',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Dismissal reason ──────────────────────────────────────
                if (widget.status == 'dismissed' &&
                    widget.dismissReason != null) ...[
                  const Text('REASON FOR DISMISSAL',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.grey)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[100]!),
                    ),
                    child: Text(widget.dismissReason!,
                        style: TextStyle(
                            color: Colors.red[900],
                            fontSize: 14,
                            fontStyle: FontStyle.italic)),
                  ),
                  const SizedBox(height: 30),
                ],

                // ── Action buttons ────────────────────────────────────────
                BlocBuilder<AdminCubit, AdminState>(
                  builder: (context, state) {
                    String liveStatus = widget.status;
                    if (state is AdminLoaded) {
                      final match = state.reports.firstWhere(
                        (r) => r['id']?.toString() == widget.reportId,
                        orElse: () => {},
                      );
                      if (match.isNotEmpty) {
                        liveStatus = match['status']?.toString() ??
                            (match['verified'] == true
                                ? 'verified'
                                : 'pending');
                      }
                    }
                    if (liveStatus == 'pending') {
                      return Column(children: [
                        _actionButton(context, 'Verify', Colors.green),
                        const SizedBox(height: 12),
                        _actionButton(context, 'Dismiss', Colors.red),
                      ]);
                    } else if (liveStatus == 'verified') {
                      return _actionButton(context, 'Dismiss', Colors.red);
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}