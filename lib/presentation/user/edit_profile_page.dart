import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Avatar preset definitions (mirrors signup_page / profile_page) ───────────
class _AvatarPreset {
  final String key;
  final Color bg;
  final Color icon;
  const _AvatarPreset(this.key, this.bg, this.icon);
}

const List<_AvatarPreset> _presets = [
  _AvatarPreset('avatar_blue',   Color(0xFFE8F0FE), Color(0xFF3B71FE)),
  _AvatarPreset('avatar_amber',  Color(0xFFFFF3E0), Color(0xFFFF9800)),
  _AvatarPreset('avatar_teal',   Color(0xFFE0F2F1), Color(0xFF009688)),
  _AvatarPreset('avatar_purple', Color(0xFFF3E5F5), Color(0xFF9C27B0)),
  _AvatarPreset('avatar_rose',   Color(0xFFFFEBEE), Color(0xFFE91E63)),
];

Color _presetBg(String? key) {
  try { return _presets.firstWhere((p) => p.key == key).bg; }
  catch (_) { return const Color(0xFFE8F0FE); }
}

Color _presetIcon(String? key) {
  try { return _presets.firstWhere((p) => p.key == key).icon; }
  catch (_) { return const Color(0xFF3B71FE); }
}

// ─────────────────────────────────────────────────────────────────────────────

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _usernameCtrl = TextEditingController();
  final _client = Supabase.instance.client;

  // ── Avatar state ──────────────────────────────────────────────────────────
  File?   _imageFile;        // newly picked photo, overrides everything else
  String? _selectedPreset;   // newly chosen preset, overrides the saved avatar
  String? _existingAvatar;   // whatever is currently saved (preset key OR a URL)
  String? _email;            // display-only

  bool _isLoading  = true;
  bool _isSaving   = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) { setState(() => _isLoading = false); return; }

      final data = await _client
          .from('profiles')
          .select('username, avatar_url, email')
          .eq('id', uid)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _usernameCtrl.text = (data?['username'] as String?) ?? '';
          _existingAvatar    = data?['avatar_url'] as String?;
          _email             = data?['email'] as String? ?? _client.auth.currentUser?.email;
          _isLoading         = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Avatar picker bottom sheet (same as signup) ──────────────────────────
  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AvatarPickerSheet(
        onCamera: () async {
          Navigator.pop(context);
          await _pickImage(ImageSource.camera);
        },
        onGallery: () async {
          Navigator.pop(context);
          await _pickImage(ImageSource.gallery);
        },
        onPreset: (key) {
          Navigator.pop(context);
          setState(() { _selectedPreset = key; _imageFile = null; });
        },
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 600,
    );
    if (picked == null) return;
    setState(() { _imageFile = File(picked.path); _selectedPreset = null; });
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) {
      setState(() => _errorMsg = "Please enter a username.");
      return;
    }
    if (username.length < 3) {
      setState(() => _errorMsg = "Username must be at least 3 characters.");
      return;
    }

    setState(() { _isSaving = true; _errorMsg = null; });

    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception("No active session.");

      String? avatarValue = _existingAvatar;

      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        final ext   = _imageFile!.path.split('.').last;
        final path  = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

        await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );
        avatarValue = '${_client.storage.from('avatars').getPublicUrl(path)}'
            '?t=${DateTime.now().millisecondsSinceEpoch}';
      } else if (_selectedPreset != null) {
        avatarValue = _selectedPreset;
      }

      await _client.from('profiles').upsert({
        'id':         uid,
        'username':   username,
        'avatar_url': avatarValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✅ Profile updated!"),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context, true); // tell ProfilePage to refresh
    } catch (e) {
      setState(() => _errorMsg = "Could not save changes: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Edit Profile",
            style: TextStyle(color: Color(0xFF22355F), fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B71FE)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),
                Center(
                  child: Text("Update your SafeWalk profile",
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ),
                const SizedBox(height: 32),

                // ── Avatar picker ─────────────────────────────────────────────
                Center(child: _buildAvatarPicker()),
                const SizedBox(height: 32),

                // ── Username ──────────────────────────────────────────────────
                _label("Username"),
                const SizedBox(height: 8),
                _field(
                  controller: _usernameCtrl,
                  hint: "e.g. ahmad_faris",
                  icon: Icons.alternate_email_rounded,
                ),
                const SizedBox(height: 6),
                Text("  This is how other users will see you — including on your comments.",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                const SizedBox(height: 20),

                // ── Email (read-only) ─────────────────────────────────────────
                _label("Email"),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.email_outlined, color: Colors.grey.shade400, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_email ?? '—',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    ),
                    Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 16),
                  ]),
                ),
                const SizedBox(height: 6),
                Text("  Email can't be changed here for security reasons.",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                const SizedBox(height: 28),

                // ── Error ─────────────────────────────────────────────────────
                if (_errorMsg != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(_errorMsg!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Save ──────────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B71FE),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Save",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 48),
              ]),
            ),
    );
  }

  // ── Avatar picker widget (same visual as signup) ──────────────────────────
  Widget _buildAvatarPicker() {
    final bool hasCustomFile = _imageFile != null;
    final bool hasNetworkUrl = !hasCustomFile && _selectedPreset == null &&
        _existingAvatar != null && _existingAvatar!.startsWith('http');
    final String presetKey = _selectedPreset ?? (hasNetworkUrl ? 'avatar_blue' : (_existingAvatar ?? 'avatar_blue'));

    final Color bgColor = (hasCustomFile || hasNetworkUrl)
        ? Colors.transparent
        : _presetBg(presetKey);
    final Color iconColor = _presetIcon(presetKey);

    return GestureDetector(
      onTap: _showAvatarPicker,
      child: Stack(alignment: Alignment.bottomRight, children: [
        CircleAvatar(
          radius: 52,
          backgroundColor: bgColor,
          backgroundImage: hasCustomFile
              ? FileImage(_imageFile!)
              : hasNetworkUrl
                  ? NetworkImage(_existingAvatar!) as ImageProvider
                  : null,
          child: (!hasCustomFile && !hasNetworkUrl)
              ? Icon(Icons.person_rounded, size: 52, color: iconColor)
              : null,
        ),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Color(0xFF3B71FE),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
        ),
      ]),
    );
  }

  // ── Shared field builder ──────────────────────────────────────────────────
  Widget _label(String text) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF22355F)));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3B71FE), width: 1.5),
        ),
      ),
    );
  }
}

// ── Avatar picker bottom sheet ─────────────────────────────────────────────────

class _AvatarPickerSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final void Function(String key) onPreset;

  const _AvatarPickerSheet({
    required this.onCamera,
    required this.onGallery,
    required this.onPreset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          const Text("Profile Picture",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF22355F))),
          const SizedBox(height: 18),

          Row(children: [
            Expanded(child: _sourceBtn(
              icon: Icons.camera_alt_rounded,
              label: "Camera",
              color: const Color(0xFF3B71FE),
              onTap: onCamera,
            )),
            const SizedBox(width: 12),
            Expanded(child: _sourceBtn(
              icon: Icons.photo_library_rounded,
              label: "Gallery",
              color: const Color(0xFF009688),
              onTap: onGallery,
            )),
          ]),

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),

          Align(
            alignment: Alignment.centerLeft,
            child: Text("Or choose an avatar",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 14),

          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _presets.map((p) {
            return GestureDetector(
              onTap: () => onPreset(p.key),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: p.bg,
                child: Icon(Icons.person_rounded, color: p.icon, size: 26),
              ),
            );
          }).toList()),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _sourceBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }
}