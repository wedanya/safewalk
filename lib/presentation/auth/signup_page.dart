import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
// ignore: unnecessary_import
import 'package:flutter/foundation.dart';

// ── Avatar preset definitions (mirrors profile_page) ──────────────────────────
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

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // ── Controllers ───────────────────────────────────────────────────────────
  final _usernameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  // ── Avatar state ──────────────────────────────────────────────────────────
  File?   _imageFile;          // custom photo from camera/gallery
  String? _selectedPreset;     // e.g. 'avatar_blue'
  // If neither is set → default avatar_blue on submit

  // ── UI state ──────────────────────────────────────────────────────────────
  bool    _obscurePass    = true;
  bool    _obscureConfirm = true;
  bool    _isLoading      = false;
  String? _errorMsg;

  final _client = Supabase.instance.client;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _setError(String? m) => setState(() { _errorMsg = m; _isLoading = false; });
  void _setLoading()        => setState(() { _errorMsg = null; _isLoading = true; });

  String? _validate() {
    if (_usernameCtrl.text.trim().isEmpty) return "Please enter a username.";
    if (_usernameCtrl.text.trim().length < 3) return "Username must be at least 3 characters.";
    if (_emailCtrl.text.trim().isEmpty)    return "Please enter your email.";
    if (!_emailCtrl.text.contains('@'))    return "Please enter a valid email.";
    if (_passwordCtrl.text.length < 6)     return "Password must be at least 6 characters.";
    if (_passwordCtrl.text != _confirmCtrl.text) return "Passwords do not match.";
    return null;
  }

  // ── Avatar picker bottom sheet ────────────────────────────────────────────
  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AvatarPickerSheet(
        selectedPreset: _selectedPreset,
        hasCustomImage: _imageFile != null,
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

  // ── Sign up ───────────────────────────────────────────────────────────────
  Future<void> _signUp() async {
    final err = _validate();
    if (err != null) { _setError(err); return; }

    _setLoading();

    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final username = _usernameCtrl.text.trim();

    try {
      // 1. Create auth account
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      if (!mounted || res.user == null) {
        _setError("Sign up failed. Please try again.");
        return;
      }

      final uid = res.user!.id;

      // 2. Resolve avatar value
      String avatarValue = _selectedPreset ?? 'avatar_blue';

      if (_imageFile != null) {
        // Upload photo to Supabase Storage → get public URL
        final bytes = await _imageFile!.readAsBytes();
        final ext   = _imageFile!.path.split('.').last;
        final path  = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

        await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );
        avatarValue = _client.storage.from('avatars').getPublicUrl(path);
      }

      // 3. Upsert profile row
      await _client.from('profiles').upsert({
        'id':         uid,
        'username':   username,
        'email':      email,
        'avatar_url': avatarValue,
      });

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.session != null) {
        // Email confirmation OFF in Supabase — go straight in
        // (shouldn't happen with confirm enabled, but handle gracefully)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("🎉 Welcome to SafeWalk!"),
            backgroundColor: Colors.green,
          ));
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (r) => false,
          );
        }
      } else {
        // Email confirmation ON — tell user to check inbox
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
              "📧 Verification email sent! Please check your inbox and verify before logging in.",
              maxLines: 3,
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ));
          Navigator.pop(context); // back to login
        }
      }
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError(e.toString());
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
        title: const Text("Sign Up",
            style: TextStyle(color: Color(0xFF22355F), fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Center(
            child: Text("Set up your SafeWalk profile",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ),
          const SizedBox(height: 32),

          // ── Avatar picker ─────────────────────────────────────────────────
          Center(child: _buildAvatarPicker()),
          const SizedBox(height: 32),

          // ── Username ──────────────────────────────────────────────────────
          _label("Username"),
          const SizedBox(height: 8),
          _field(
            controller: _usernameCtrl,
            hint: "e.g. ahmad_faris562",
            icon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 6),
          Text("  This is how other users will see you.",
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          const SizedBox(height: 20),

          // ── Email ─────────────────────────────────────────────────────────
          _label("Email"),
          const SizedBox(height: 8),
          _field(
            controller: _emailCtrl,
            hint: "Enter your email",
            icon: Icons.email_outlined,
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 6),
          // Verification notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 14, color: Color(0xFF3B71FE)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "A verification link will be sent to this email. You must verify before logging in.",
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Password ──────────────────────────────────────────────────────
          _label("Password"),
          const SizedBox(height: 8),
          _field(
            controller: _passwordCtrl,
            hint: "At least 6 characters",
            icon: Icons.lock_outline,
            obscure: _obscurePass,
            toggleObscure: () => setState(() => _obscurePass = !_obscurePass),
          ),
          const SizedBox(height: 20),

          // ── Confirm password ──────────────────────────────────────────────
          _label("Confirm Password"),
          const SizedBox(height: 8),
          _field(
            controller: _confirmCtrl,
            hint: "Re-enter your password",
            icon: Icons.lock_outline,
            obscure: _obscureConfirm,
            toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
            onSubmit: (_) => _signUp(),
          ),
          const SizedBox(height: 28),

          // ── Error ─────────────────────────────────────────────────────────
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

          // ── Submit ────────────────────────────────────────────────────────
          SizedBox(
  width: double.infinity, height: 56,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF3B71FE),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
    onPressed: _isLoading ? null : () async {
      // ── TEMPORARY DEBUG TEST — remove this block once the push
      // pipeline is confirmed working, then restore to just: _signUp
      final res = await Supabase.instance.client.functions.invoke(
        'send-push',
        body: {
          'record': {
            'user_id': 'c24ed0aa-0f40-4641-9d1f-e706ae03265c',
            'title': 'Test push',
            'body': 'Testing the pipeline directly',
          }
        },
      );
      debugPrint('PUSH TEST status: ${res.status}');
      debugPrint('PUSH TEST data: ${res.data}');
      // ── end debug block ──

      await _signUp();
    },
    child: _isLoading
        ? const SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : const Text("Create Account",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
  ),
),
const SizedBox(height: 20),

          // ── Back to login ─────────────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text("Already have an account?  ",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text("Log In",
                  style: TextStyle(color: Color(0xFF3B71FE),
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 48),
        ]),
      ),
    );
  }

  // ── Avatar picker widget ──────────────────────────────────────────────────
  Widget _buildAvatarPicker() {
    final bool hasCustom = _imageFile != null;
    final Color bgColor  = hasCustom
        ? Colors.transparent
        : _presetBg(_selectedPreset ?? 'avatar_blue');
    final Color iconColor = _presetIcon(_selectedPreset ?? 'avatar_blue');

    return GestureDetector(
      onTap: _showAvatarPicker,
      child: Stack(alignment: Alignment.bottomRight, children: [
        CircleAvatar(
          radius: 52,
          backgroundColor: bgColor,
          backgroundImage: hasCustom ? FileImage(_imageFile!) : null,
          child: !hasCustom
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
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    VoidCallback? toggleObscure,
    void Function(String)? onSubmit,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      onSubmitted: onSubmit,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.grey.shade400, size: 20,
                ),
                onPressed: toggleObscure,
              )
            : null,
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

class _AvatarPickerSheet extends StatefulWidget {
  final String? selectedPreset;
  final bool hasCustomImage;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final void Function(String key) onPreset;

  const _AvatarPickerSheet({
    required this.selectedPreset,
    required this.hasCustomImage,
    required this.onCamera,
    required this.onGallery,
    required this.onPreset,
  });

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  late String? _hoveredPreset = widget.selectedPreset;

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
          // Handle bar
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          const Text("Profile Picture",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF22355F))),
          const SizedBox(height: 18),

          // Camera / Gallery options
          Row(children: [
            Expanded(child: _sourceBtn(
              icon: Icons.camera_alt_rounded,
              label: "Camera",
              color: const Color(0xFF3B71FE),
              onTap: widget.onCamera,
            )),
            const SizedBox(width: 12),
            Expanded(child: _sourceBtn(
              icon: Icons.photo_library_rounded,
              label: "Gallery",
              color: const Color(0xFF009688),
              onTap: widget.onGallery,
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

          // Preset avatar row
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _presets.map((p) {
            final bool sel = _hoveredPreset == p.key && !widget.hasCustomImage;
            return GestureDetector(
              onTap: () {
                setState(() => _hoveredPreset = p.key);
                widget.onPreset(p.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sel ? p.icon : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: p.bg,
                  child: Icon(Icons.person_rounded, color: p.icon, size: 26),
                ),
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
          // ignore: deprecated_member_use
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),  // ignore: deprecated_member_use
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