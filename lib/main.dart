import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'presentation/auth/login_page.dart';
import 'presentation/user/user_main.dart';
import 'presentation/admin/admin_main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mrudrkobwnxnmiyekwhp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ydWRya29id254bm1peWVrd2hwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1NjExNzEsImV4cCI6MjA5NDEzNzE3MX0.OV_MwKoR4F8L-jMJHzuF2BaBIdfmIdIt80a_ODmgeIg',
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const SafeWalkApp());
}

class SafeWalkApp extends StatelessWidget {
  const SafeWalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeWalk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B71FE),
          primary: const Color(0xFF3B71FE),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool    _checking    = true;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      // Check for an existing valid session — do NOT auto-refresh,
      // so a logged-out user always lands on LoginPage.
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        _resolve(const LoginPage());
        return;
      }

      final uid = session.user.id;

      // Check role
      final admin = await Supabase.instance.client
          .from('admins')
          .select('id')
          .eq('id', uid)
          .maybeSingle();

      _resolve(admin != null ? const AdminMain() : const UserMain());
    } catch (_) {
      // Any error → send to login
      _resolve(const LoginPage());
    }
  }

  void _resolve(Widget page) {
    if (mounted) setState(() { _destination = page; _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3B71FE)),
        ),
      );
    }
    return _destination!;
  }
}