import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin/admin_main.dart';
import '../user/user_main.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure       = true;
  bool _isLoading     = false;
  String? _errorMsg;

  final _client = Supabase.instance.client;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  void _setError(String? msg) => setState(() { _errorMsg = msg; _isLoading = false; });
  void _setLoading()          => setState(() { _errorMsg = null; _isLoading = true; });

  // ── Route by role ─────────────────────────────────────────────────────────
  Future<void> _routeByRole() async {
    if (!mounted) return;
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) { _goUser(); return; }

      // Check if this user exists in the admins table
      final admin = await _client
          .from('admins')
          .select('id')
          .eq('id', uid)
          .maybeSingle();

      if (!mounted) return;
      if (admin != null) {
        _goAdmin();
      } else {
        _goUser();
      }
    } catch (_) {
      // If check fails, default to user
      _goUser();
    }
  }

  void _goUser() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const UserMain()),
    );
  }

  void _goAdmin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminMain()),
    );
  }

  // ── 1. Email / password login ─────────────────────────────────────────────
  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _setError("Please enter your email and password.");
      return;
    }
    _setLoading();
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      await _routeByRole();
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError("Connection error. Please try again.");
    }
  }

  // ── 2. Forgot password ────────────────────────────────────────────────────
  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _setError("Enter your email above first, then tap Forgot Password.");
      return;
    }
    _setLoading();
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.safewalk://login-callback/',
      );
      _setError(null);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("📧 Password reset email sent!"),
          backgroundColor: Colors.blue,
        ));
      }
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError("Connection error. Please try again.");
    }
  }

  // ── 4. Google OAuth ───────────────────────────────────────────────────────
  Future<void> _googleLogin() async {
    _setLoading();
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.safewalk://login-callback/',
      );
      // Supabase handles the redirect; listen via onAuthStateChange in main.dart
      setState(() => _isLoading = false);
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError("Google sign-in failed. Please try again.");
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(children: [
          const SizedBox(height: 80),
          const CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFFE8EFFF),
            child: Icon(Icons.shield_outlined, size: 50, color: Color(0xFF3B71FE)),
          ),
          const SizedBox(height: 30),
          const Text("Your safety starts here.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Real-time safety monitoring for Kuala Terengganu residents.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey, fontSize: 14)),
          const SizedBox(height: 40),

          // ── Email field ──────────────────────────────────────────────────
          _buildLabel("Email"),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDeco("Enter your email", null),
          ),
          const SizedBox(height: 20),

          // ── Password field ───────────────────────────────────────────────
          _buildLabel("Password"),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            onSubmitted: (_) => _login(),
            decoration: _inputDeco(
              "Enter your password",
              IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _forgotPassword,
              child: const Text("Forgot Password?"),
            ),
          ),

          // ── Error message ────────────────────────────────────────────────
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
            const SizedBox(height: 12),
          ],

          // ── Login button ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B71FE),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Login",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 15),

          // ── Sign up button ───────────────────────────────────────────────
          SizedBox(
            width: double.infinity, height: 55,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF3B71FE)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _isLoading ? null : () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SignUpPage()));
              },
              child: const Text("Sign Up",
                  style: TextStyle(color: Color(0xFF3B71FE), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),

          const SizedBox(height: 30),
          const Text("or continue with", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),

          // ── Google login ─────────────────────────────────────────────────
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _isLoading ? null : _googleLogin,
            icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
            label: const Text("Continue with Google",
                style: TextStyle(color: Colors.black)),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _buildLabel(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  InputDecoration _inputDeco(String hint, Widget? suffix) => InputDecoration(
    hintText: hint,
    suffixIcon: suffix,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF3B71FE), width: 1.5),
    ),
  );
}