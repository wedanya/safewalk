import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/user_cubit/report_cubit.dart';
import '../../shared/offline_banner.dart';

class NewReportPage extends StatefulWidget {
  final VoidCallback? onSubmitSuccess;
  const NewReportPage({super.key, this.onSubmitSuccess});

  @override
  State<NewReportPage> createState() => _NewReportPageState();
}

class _NewReportPageState extends State<NewReportPage> {
  final _detailsCtrl = TextEditingController();
  File? _pickedImage;
  bool _uploadingImage = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked == null) return;
    setState(() => _pickedImage = File(picked.path));
  }

  void _showImageSourceSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF3B71FE)),
            title: const Text('Take a Photo'),
            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.image_rounded, color: Color(0xFF3B71FE)),
            title: const Text('Choose from Gallery'),
            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
          ),
          if (_pickedImage != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(ctx); setState(() => _pickedImage = null); },
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Future<String?> _uploadImage(String userId) async {
    if (_pickedImage == null) return null;
    setState(() => _uploadingImage = true);
    try {
      final ext  = _pickedImage!.path.split('.').last;
      final path = '$userId/report_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await _pickedImage!.readAsBytes();
      await Supabase.instance.client.storage
          .from('report-images')
          .uploadBinary(path, bytes,
              fileOptions: FileOptions(contentType: 'image/$ext', upsert: true));
      return Supabase.instance.client.storage
          .from('report-images')
          .getPublicUrl(path);
    } catch (e) {
      return null;
    } finally {
      setState(() => _uploadingImage = false);
    }
  }

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(BuildContext context) async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final imageUrl = await _uploadImage(uid);
    if (context.mounted) {
      context.read<ReportCubit>().submitReport(
        details: _detailsCtrl.text,
        imageUrl: imageUrl,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportCubit()..init(),
      child: BlocConsumer<ReportCubit, ReportState>(
        listener: (context, state) {
          if (state is ReportSubmitSuccess) {
            _detailsCtrl.clear();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.savedOffline
                  ? "📦 Saved offline — will upload when connected."
                  : "✅ Report submitted! Pending admin verification."),
              backgroundColor: state.savedOffline ? Colors.orange : Colors.green,
              duration: const Duration(seconds: 3),
            ));
            widget.onSubmitSuccess?.call();
          } else if (state is ReportSubmitFailure) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: state.savedOffline ? Colors.orange : Colors.red,
            ));
          } else if (state is ReportLocationReady && state.lastSyncedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                "☁️ ${state.lastSyncedCount} offline report${state.lastSyncedCount > 1 ? 's' : ''} uploaded!",
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ));
          }
        },
        builder: (context, state) {
          final isSubmitting = state is ReportSubmitting;
          final locationState = state is ReportSubmitting
              ? state.locationState
              : (state is ReportLocationReady ? state : null);

          final isOnline = locationState?.isOnline ?? true;
          final pendingCount = locationState?.pendingCount ?? 0;
          final selectedType = locationState?.selectedType ?? '';
          final isFetchingLocation = state is ReportFetchingLocation;

          return Scaffold(
            backgroundColor: const Color(0xFFF0F2F8),
            appBar: AppBar(
              backgroundColor: const Color(0xFFF0F2F8),
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => widget.onSubmitSuccess?.call(),
              ),
              title: const Text("New Report",
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18)),
              centerTitle: true,
              actions: [
                if (pendingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: isOnline
                          ? () => context.read<ReportCubit>().syncPendingReports()
                          : null,
                      child: Stack(alignment: Alignment.topRight, children: [
                        const Icon(Icons.cloud_upload_outlined, color: Colors.orange),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Text('$pendingCount',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
            body: Column(children: [
              OfflineBanner(
                isOnline: isOnline,
                pendingCount: pendingCount,
                onRetry: isOnline ? () => context.read<ReportCubit>().syncPendingReports() : null,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text("Report Type",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF22355F))),
                      Text("Step 1 of 3",
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    ]),
                    const SizedBox(height: 15),
                    _buildCategoryGrid(context, selectedType),
                    const SizedBox(height: 25),

                    const Text("Incident Location",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF22355F))),
                    const SizedBox(height: 12),
                    _buildLocationCard(context,
                        isFetching: isFetchingLocation,
                        label: locationState?.locationLabel ?? "Fetching location..."),
                    const SizedBox(height: 25),

                    const Text("Add Photo (Optional)",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF22355F))),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _showImageSourceSheet(context),
                      child: _pickedImage != null
                          ? Stack(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(_pickedImage!,
                                    width: double.infinity, height: 180, fit: BoxFit.cover),
                              ),
                              Positioned(top: 10, right: 10,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                              if (_uploadingImage)
                                Positioned.fill(child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                                )),
                            ])
                          : Container(
                              width: double.infinity, height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF3B71FE).withValues(alpha: 0.3), width: 1.5,
                                    style: BorderStyle.solid),
                              ),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade400, size: 32),
                                const SizedBox(height: 8),
                                Text('Tap to add a photo', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                                Text('Optional — helps admin verify faster',
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                              ]),
                            ),
                    ),
                    const SizedBox(height: 20),
                    const Text("Additional Details",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF22355F))),
                    const SizedBox(height: 10),

                    // ── WHITE text box ──────────────────────────────────────
                    TextField(
                      controller: _detailsCtrl,
                      maxLines: 5,
                      maxLength: 500,
                      style: const TextStyle(color: Color(0xFF22355F), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Describe the situation...",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white, // ← WHITE background
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Color(0xFF3B71FE), width: 1.5)),
                        counterText: "Max 500 characters",
                        counterStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isOnline ? Colors.orange : Colors.grey).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isOnline ? Colors.orange.shade200 : Colors.grey.shade300),
                      ),
                      child: Row(children: [
                        Icon(isOnline ? Icons.info_outline : Icons.wifi_off_rounded,
                            color: isOnline ? Colors.orange : Colors.grey, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isOnline
                                ? "Reports are reviewed by an admin before appearing on the map."
                                : "You're offline. Report will be saved and uploaded when reconnected.",
                            style: TextStyle(
                                color: isOnline ? Colors.orange : Colors.grey, fontSize: 12),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: isSubmitting || isFetchingLocation
                          ? null
                          : () async => await _handleSubmit(context),
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(isOnline ? Icons.send : Icons.save_outlined, size: 18),
                      label: Text(
                        isSubmitting ? "Processing..." : (isOnline ? "Submit Report" : "Save Offline"),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOnline ? const Color(0xFF3B71FE) : Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 58),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 130),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context,
      {required bool isFetching, required String label}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          child: SizedBox(
            height: 130, width: double.infinity,
            child: isFetching
                ? const ColoredBox(
                    color: Color(0xFFE8EDF5),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF3B71FE), strokeWidth: 2)))
                : Stack(children: [
                    CustomPaint(size: const Size(double.infinity, 130), painter: _MapGridPainter()),
                    CustomPaint(size: const Size(double.infinity, 130), painter: _MapRoadPainter()),
                    const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.location_on, color: Color(0xFF3B71FE), size: 40,
                          shadows: [Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))]),
                      SizedBox(height: 22),
                    ])),
                  ]),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
          child: Row(children: [
            Icon(Icons.my_location, size: 15, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis)),
            GestureDetector(
              onTap: () => context.read<ReportCubit>().fetchLocation(isOnline: true),
              child: const Icon(Icons.refresh, size: 18, color: Color(0xFF3B71FE)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCategoryGrid(BuildContext context, String selectedType) {
    final cats = [
      {'icon': Icons.visibility_outlined, 'title': "Suspicious Activity"},
      {'icon': Icons.warning_amber_rounded, 'title': "Hazardous Road"},
      {'icon': Icons.shopping_bag_outlined, 'title': "Theft/Robbery"},
      {'icon': Icons.nightlight_outlined, 'title': "Poor Lighting"},
      {'icon': Icons.shield_outlined, 'title': "Harassment"},
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.5),
      itemBuilder: (_, i) {
        final cat = cats[i];
        final bool sel = selectedType == cat['title'];
        return GestureDetector(
          onTap: () => context.read<ReportCubit>().selectType(cat['title'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFF3B71FE) : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: sel ? const Color(0xFF3B71FE) : Colors.transparent, width: 2),
              boxShadow: sel
                  ? [BoxShadow(color: const Color(0xFF3B71FE).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sel ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFEEF1FB),
                  shape: BoxShape.circle,
                ),
                child: Icon(cat['icon'] as IconData,
                    color: sel ? Colors.white : const Color(0xFF3B71FE), size: 22),
              ),
              const SizedBox(height: 8),
              Text(cat['title'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: sel ? Colors.white : const Color(0xFF22355F),
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
          ),
        );
      },
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFE8F0E9));
    final paint = Paint()..color = const Color(0xFFD0DCE0)..strokeWidth = 0.7;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final blockPaint = Paint()..color = const Color(0xFFD4DDD5);
    for (final b in [Rect.fromLTWH(20,15,40,25),Rect.fromLTWH(75,10,30,20),Rect.fromLTWH(160,20,50,30),
        Rect.fromLTWH(230,12,35,22),Rect.fromLTWH(20,80,45,28),Rect.fromLTWH(150,75,55,35),Rect.fromLTWH(240,82,40,25)]) {
      canvas.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(3)), blockPaint);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(95,55,55,45), const Radius.circular(6)),
        Paint()..color = const Color(0xFFC8DFC9));
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}

class _MapRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()..color = Colors.white..strokeWidth = 7..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.45), road);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), road);
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), road);
    canvas.drawLine(Offset(size.width * 0.72, 0), Offset(size.width * 0.72, size.height), road);
    final dash = Paint()..color = const Color(0xFFD4C97A)..strokeWidth = 1.2;
    for (double x = 0; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, size.height * 0.45), Offset(x + 9, size.height * 0.45), dash);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}