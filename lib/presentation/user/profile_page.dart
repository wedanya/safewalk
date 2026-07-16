import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/login_page.dart';
import 'edit_profile_page.dart';
import 'notification_preferences_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ─── State ───────────────────────────────────────────────────────────────
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  int _reportCount = 0;
  List<Map<String, dynamic>> _contacts = [];

  // Inline Expandable tracking state
  String? _expandedSettingId;

  // ─── Supabase client shorthand ────────────────────────────────────────────
  final _db = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ─── 1. MASTER LOADER ────────────────────────────────────────────────────
  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchProfile(),
      _fetchReportCount(),
      _fetchContacts(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  // ─── 2. FETCH PROFILE from `profiles` table ───────────────────────────────
  Future<void> _fetchProfile() async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return;

      final data = await _db
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _profile = data;
        });
      }
    } catch (e) {
      debugPrint('Profile fetch error: $e');
    }
  }

  // ─── 3. COUNT USER REPORTS from `hotspots` table ─────────────────────────
  Future<void> _fetchReportCount() async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return;

      final response = await _db
          .from('hotspots')
          .select('id')
          .eq('user_id', uid)
          .eq('source', 'user_report');

      if (mounted) {
        setState(() => _reportCount = (response as List).length);
      }
    } catch (e) {
      debugPrint('Report count error: $e');
    }
  }

  // ─── 4. FETCH EMERGENCY CONTACTS from `emergency_contacts` table ──────────
  Future<void> _fetchContacts() async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return;

      final data = await _db
          .from('emergency_contacts')
          .select()
          .eq('user_id', uid)
          .order('name');

      if (mounted) {
        setState(() => _contacts = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint('Contacts fetch error: $e');
    }
  }

  // ─── 5. Notification preferences now live entirely in
  //        NotificationPreferencesPage — see _buildAccountSettingsSection.

  // ─── 6. ADD CONTACT bottom sheet ─────────────────────────────────────────
  void _showAddContactDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B71FE).withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF3B71FE), size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  "Add Emergency Contact",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF22355F)),
                ),
                const SizedBox(height: 4),
                Text(
                  "This person will be alerted in emergencies",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 24),
                _buildSheetField(
                  controller: nameCtrl,
                  label: "Full Name",
                  hint: "e.g. Ahmad Faris",
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 14),
                _buildSheetField(
                  controller: phoneCtrl,
                  label: "Phone Number",
                  hint: "e.g. 012-3456789",
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 28),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _addContact(nameCtrl.text.trim(), phoneCtrl.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B71FE),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text("Save Contact", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF22355F))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: Color(0xFF22355F)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF3B71FE), size: 20),
            filled: true,
            fillColor: const Color(0xFFF5F7FF),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF3B71FE), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addContact(String name, String phone) async {
    if (name.isEmpty || phone.isEmpty) return;
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return;

      await _db.from('emergency_contacts').insert({
        'user_id': uid,
        'name': name,
        'phone': phone,
        'icon_type': 'person',
      });

      _fetchContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contact added!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── 7. DELETE CONTACT ────────────────────────────────────────────────────
  Future<void> _deleteContact(String contactId) async {
    try {
      await _db.from('emergency_contacts').delete().eq('id', contactId);
      _fetchContacts();
    } catch (e) {
      debugPrint('Delete contact error: $e');
    }
  }


  // ─── AVATAR UTILITIES & ACTIONS ───────────────────────────────────────────
  Widget _getPresetAvatarIcon(String? avatarKey) {
    const double iconSize = 48.0;

    switch (avatarKey) {
      case 'avatar_blue':
        return const Icon(Icons.person_rounded, size: iconSize, color: Color(0xFF3B71FE));
      case 'avatar_amber':
        return const Icon(Icons.person_rounded, size: iconSize, color: Color(0xFFFF9800));
      case 'avatar_teal':
        return const Icon(Icons.person_rounded, size: iconSize, color: Color(0xFF009688));
      case 'avatar_purple':
        return const Icon(Icons.person_rounded, size: iconSize, color: Color(0xFF9C27B0));
      case 'avatar_rose':
        return const Icon(Icons.person_rounded, size: iconSize, color: Color(0xFFE91E63));
      default:
        return const Icon(Icons.person_rounded, size: iconSize, color: Color(0xFF3B71FE));
    }
  }

  Color _getPresetBackgroundColor(String? avatarKey) {
    switch (avatarKey) {
      case 'avatar_blue': return const Color(0xFFE8F0FE);
      case 'avatar_amber': return const Color(0xFFFFF3E0);
      case 'avatar_teal': return const Color(0xFFE0F2F1);
      case 'avatar_purple': return const Color(0xFFF3E5F5);
      case 'avatar_rose': return const Color(0xFFFFEBEE);
      default: return const Color(0xFF3B71FE).withAlpha(25);
    }
  }

  void _showAvatarPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Change Profile Picture",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF22355F)),
                ),
                const SizedBox(height: 15),
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded, color: Color(0xFF3B71FE)),
                  title: const Text("Take a New Photo"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadCustomImage(true);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_search_rounded, color: Color(0xFF3B71FE)),
                  title: const Text("Choose from Gallery"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadCustomImage(false);
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("Or choose an illustrative avatar:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                const SizedBox(height: 8),
                _buildPresetRow(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresetRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildAvatarPresetBtn('avatar_blue', const Color(0xFFE8F0FE), const Color(0xFF3B71FE)),
        _buildAvatarPresetBtn('avatar_amber', const Color(0xFFFFF3E0), const Color(0xFFFF9800)),
        _buildAvatarPresetBtn('avatar_teal', const Color(0xFFE0F2F1), const Color(0xFF009688)),
        _buildAvatarPresetBtn('avatar_purple', const Color(0xFFF3E5F5), const Color(0xFF9C27B0)),
        _buildAvatarPresetBtn('avatar_rose', const Color(0xFFFFEBEE), const Color(0xFFE91E63)),
      ],
    );
  }

  Widget _buildAvatarPresetBtn(String key, Color bgColor, Color iconColor) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _updateAvatarDataInSupabase(key);
      },
      child: CircleAvatar(
        radius: 24,
        backgroundColor: bgColor,
        child: Icon(Icons.person_rounded, color: iconColor, size: 24),
      ),
    );
  }

  Future<void> _pickAndUploadCustomImage(bool fromCamera) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 60,
    );

    if (pickedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final user = _db.auth.currentUser;
      if (user == null) throw Exception("User session not found");

      final fileBytes = await pickedFile.readAsBytes();
      final fileExtension = pickedFile.path.split('.').last;
      final filePath = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      await _db.storage.from('avatars').uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

final cacheBustedUrl = '${_db.storage.from('avatars').getPublicUrl(filePath)}?t=${DateTime.now().millisecondsSinceEpoch}';      await _db.from('profiles').upsert({'id': user.id, 'avatar_url': cacheBustedUrl});
      
      await _fetchProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateAvatarDataInSupabase(String avatarValue) async {
    setState(() => _isLoading = true);
    try {
      final user = _db.auth.currentUser;
      if (user == null) return;

      await _db.from('profiles').upsert({'id': user.id, 'avatar_url': avatarValue});
      await _fetchProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save avatar: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _db.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "Profile",
          style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF22355F)),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B71FE)))
          : RefreshIndicator(
              onRefresh: _loadAll,
              color: const Color(0xFF3B71FE),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildUserHeader(),
                    const SizedBox(height: 20),
                    _buildStatsSection(),
                    const SizedBox(height: 20),
                    _buildContactsSection(),
                    const SizedBox(height: 20),
                    _buildAccountSettingsSection(),
                    const SizedBox(height: 40),
                    // ─── COPYRIGHT FOOTER ─────────────────────────────────────
                    Text(
                      "© ${DateTime.now().year} SafeWalk. All rights reserved.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── Navigate to Edit Profile, then refresh on return ────────────────────
  Future<void> _openEditProfile() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    if (changed == true) await _fetchProfile();
  }

  // ─── User Header Widget ───────────────────────────────────────────────────
  Widget _buildUserHeader() {
    // Username is the field actually written by sign-up/edit — this is also
    // what shows up on comments, so keep the header in sync with it.
    final name = (_profile?['username'] as String?) ?? "User";
    final membership = _profile?['membership'] ?? "Standard Member";
    final avatarUrl = _profile?['avatar_url'] as String?;

    final bool isNetworkImage = avatarUrl != null && avatarUrl.startsWith('http');

    return Column(
      children: [
        GestureDetector(
          onTap: _showAvatarPickerOptions,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: _getPresetBackgroundColor(avatarUrl),
                backgroundImage: isNetworkImage ? NetworkImage(avatarUrl) : null,
                child: !isNetworkImage ? _getPresetAvatarIcon(avatarUrl) : null,
              ),
              const Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF3B71FE),
                  child: Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: GestureDetector(
                  onTap: _openEditProfile,
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF22355F),
                    child: Icon(Icons.edit_rounded, size: 15, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Text(
          name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF22355F)),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF3B71FE).withAlpha(25),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            membership,
            style: const TextStyle(color: Color(0xFF3B71FE), fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ─── Stats Widget ─────────────────────────────────────────────────────────
  Widget _buildStatsSection() {
    final kmWalked = _profile?['km_walked']?.toString() ?? '0.0';

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "$kmWalked km", 
            "Distance Walked", 
            Icons.directions_walk_rounded,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildStatCard(
            "$_reportCount", 
            "Reports Made", 
            Icons.assignment_turned_in_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5), 
            blurRadius: 10, 
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF3B71FE).withAlpha(25),
            radius: 20,
            child: Icon(icon, color: const Color(0xFF3B71FE), size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value, 
            style: const TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 20, 
              color: Color(0xFF22355F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title, 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ─── Emergency Contacts Widget ────────────────────────────────────────────
  Widget _buildContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Emergency Contacts",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF22355F)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _showAddContactDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B71FE),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF3B71FE).withAlpha(76), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text("Add New", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.vibration_rounded, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                "Shake your phone to call your emergency contact if you're in danger.",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_contacts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Text(
              "No emergency contacts yet. Add one above.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ..._contacts.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildContactTile(
                c['id'] as String,
                c['name'] as String,
                c['phone'] as String,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContactTile(String id, String name, String phone) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(2), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF3B71FE).withAlpha(12),
          child: const Icon(Icons.person_pin_circle_outlined, color: Color(0xFF3B71FE)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF22355F), fontSize: 14)),
        subtitle: Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              child: CircleAvatar(
                backgroundColor: const Color(0xFF3B71FE).withAlpha(25),
                radius: 15,
                child: const Icon(Icons.call, color: Color(0xFF3B71FE), size: 16),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _deleteContact(id),
              child: const CircleAvatar(
                backgroundColor: Color(0xFFFFEEEE),
                radius: 15,
                child: Icon(Icons.delete_outline, color: Colors.red, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Account Settings Section (Sliding Expansion Architecture) ───────────
  Widget _buildAccountSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Account Settings",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF22355F)),
        ),
        const SizedBox(height: 10),
        
        // 1. Privacy & Security Accordion Panel
        _buildExpandableSettingTile(
          id: 'privacy',
          icon: Icons.lock_outline,
          title: "Privacy & Security",
          child: const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Text(
              "Account encryption safety protocols and regional tracking constraints are securely managed within your current local device session configuration details.",
              style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
            ),
          ),
        ),

        // 2. Notification Preferences — opens the dedicated page
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(2), blurRadius: 10, offset: const Offset(0, 5)),
            ],
          ),
          child: ListTile(
            leading: const Icon(Icons.notifications_none_rounded, color: Color(0xFF22355F), size: 20),
            title: const Text("Notification Preferences",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF22355F))),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationPreferencesPage()),
            ),
          ),
        ),

        // 3. Help & Support Accordion Panel
        _buildExpandableSettingTile(
          id: 'help',
          icon: Icons.help_outline_rounded,
          title: "Help & Support",
          child: const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Text(
              "Encountering application issues or technical bugs? Please contact our dedicated admin emergency support coordinator directly via email lines.",
              style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  // Master UI wrapper managing the custom expanding cross-fade animation transitions
  Widget _buildExpandableSettingTile({
    required String id,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final bool isExpanded = _expandedSettingId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(2), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: const Color(0xFF22355F), size: 20),
            title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF22355F))),
            trailing: AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: isExpanded ? 0.25 : 0.0, // Clean arrow rotation action indicator
              child: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ),
            onTap: () {
              setState(() {
                // If clicked a panel that is already expanded, collapse it; otherwise open it
                _expandedSettingId = isExpanded ? null : id;
              });
            },
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: child,
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}