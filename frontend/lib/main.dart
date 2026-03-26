import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  runApp(const PhotoSelectorApp());
}

/* ─────────────────────────── GOOGLE CLIENT ID ─────────────────────────── */
const String _kWebClientId =
    '734414556752-72q6jo53jis7v1dgrs3grbet5n3jtrha.apps.googleusercontent.com';

/* ─────────────────────────── GOOGLE SIGN-IN (Web only) ─────────────────────────── */
final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: _kWebClientId,
  scopes: ['email', 'profile'],
);

/* ─────────────────────────── THEME ─────────────────────────── */
const kGold    = Color(0xFFFFD600);
const kBg      = Color(0xFF080808);
const kSurface = Color(0xFF111111);
const kCard    = Color(0xFF181818);
const kBorder  = Color(0xFF2A2A2A);
const kText    = Color(0xFFF0F0F0);
const kMuted   = Color(0xFF666666);
const kGreen   = Color(0xFF4CAF50);
const kRed     = Color(0xFFE53935);
const kBlue    = Color(0xFF2196F3);

/* ─────────────────────────── GLOBAL SESSION ─────────────────────────── */
class AppSession {
  static String? token;
  static Map<String, dynamic>? user;

  static Map<String, String> get authHeaders => {
        'Authorization': 'Bearer ${token ?? ""}',
        'Content-Type': 'application/json',
      };
}

/* ─────────────────────────── BASE URL ─────────────────────────── */
String baseUrl() => (!kIsWeb && Platform.isAndroid)
    ? 'http://10.0.2.2:8000'
    : 'http://localhost:8000';

/* ─────────────────────────── APP ─────────────────────────── */
class PhotoSelectorApp extends StatelessWidget {
  const PhotoSelectorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "HACKX",
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        primaryColor: kGold,
        fontFamily: 'monospace',
      ),
      home: const LoginScreen(),
    );
  }
}

/* ─────────────────────────── SHARED WIDGETS ─────────────────────────── */
class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outline;
  final IconData? icon;
  const GoldButton({super.key, required this.label, this.onPressed,
      this.outline = false, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: outline ? Colors.transparent : kGold,
          foregroundColor: outline ? kGold : kBg,
          elevation: 0,
          side: outline ? const BorderSide(color: kGold, width: 1.5) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(width: 3, height: 14, color: kGold),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  color: kMuted, fontSize: 11, letterSpacing: 3,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

PreferredSizeWidget buildAppBar(String title,
    {List<Widget>? actions, bool showBack = false, VoidCallback? onBack}) {
  return AppBar(
    backgroundColor: kSurface,
    elevation: 0,
    centerTitle: false,
    automaticallyImplyLeading: showBack,
    actions: actions,
    leading: showBack
        ? IconButton(
            icon: const Icon(Icons.arrow_back, color: kGold), onPressed: onBack)
        : null,
    title: Row(
      children: [
        Container(width: 3, height: 16, color: kGold),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: kText, fontSize: 13,
                fontWeight: FontWeight.w700, letterSpacing: 3)),
      ],
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(color: kBorder, height: 1),
    ),
    iconTheme: const IconThemeData(color: kGold),
  );
}

class BreakdownBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  const BreakdownBar({super.key, required this.label, required this.value,
      required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(color: kMuted, fontSize: 9, letterSpacing: 1)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: kBorder,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(value.toStringAsFixed(1),
              style: const TextStyle(color: kMuted, fontSize: 9)),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kGold.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

/* ═══════════════════════════════════════════════════════════════════════
   1. LOGIN SCREEN
═══════════════════════════════════════════════════════════════════════ */
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── Main mode: true = register page, false = login page ──
  bool _isRegister = false;

  // ── Tab within each page: 0 = PASSWORD, 1 = OTP EMAIL ──
  int _loginTab    = 1; // Login: default OTP tab
  int _registerTab = 0; // Register: default PASSWORD tab

  // ── Shared fields ──
  final _userCtrl  = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _obscure    = true;
  bool _loading    = false;
  bool _googleLoading = false;
  String? _error;
  bool _showRegisterHint   = false;
  bool _alreadyRegistered  = false;

  // ── Registration via PASSWORD tab OTP ──
  int  _regStep        = 0; // 0=form, 1=enter otp
  final _regOtpCtrl    = TextEditingController();
  bool _regOtpLoading  = false;
  String? _regOtpError;
  String? _regOtpSuccess;

  // ── Registration via OTP EMAIL tab (new correct flow) ──
  // Step 0: enter email, Step 1: enter OTP
  int  _regOtpEmailStep     = 0;
  final _regOtpEmailCtrl    = TextEditingController(); // email field
  final _regOtpEmailCodeCtrl = TextEditingController(); // code field
  bool _regOtpEmailLoading  = false;
  String? _regOtpEmailError;
  String? _regOtpEmailSuccess;

  // ── Login OTP ──
  final _otpEmailCtrl = TextEditingController();
  final _otpCodeCtrl  = TextEditingController();
  bool _otpSent       = false;
  bool _otpLoading    = false;
  bool _isForgotPassword = false;
  String? _otpError;
  String? _otpSuccess;

  // ── Reset Password (after OTP verified) ──
  bool _resetStep = false;
  final _newPassCtrl       = TextEditingController();
  final _confirmPassCtrl   = TextEditingController();
  bool _newPassObscure     = true;
  bool _confirmPassObscure = true;
  String? _resetError;
  String? _resetSuccess;

  /* ── Username/Password login ── */
  Future<void> _submitLogin() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    if (user.isEmpty || pass.isEmpty) {
      setState(() => _error = "Please enter both username and password.");
      return;
    }
    if (user.length < 3) {
      setState(() => _error = "Username must be at least 3 characters.");
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await http.post(
        Uri.parse('${baseUrl()}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': user, 'password': pass}),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        AppSession.token = body['token'];
        AppSession.user  = Map<String, dynamic>.from(body['user']);
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } else {
        final body   = jsonDecode(resp.body);
        final detail = body['detail'] ?? 'Something went wrong.';
        if (resp.statusCode == 404) {
          setState(() { _error = detail; _showRegisterHint = true; });
        } else {
          setState(() { _error = detail; _showRegisterHint = false; });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Cannot reach server. Is the backend running?';
        _showRegisterHint = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* ── PASSWORD tab register: Step 1 — Send OTP ── */
  Future<void> _sendRegOtp() async {
    final user  = _userCtrl.text.trim();
    final pass  = _passCtrl.text;
    final email = _emailCtrl.text.trim().toLowerCase();

    if (user.isEmpty || pass.isEmpty || email.isEmpty) {
      setState(() => _error = "Please fill in username, email, and password.");
      return;
    }
    if (user.length < 3) {
      setState(() => _error = "Username must be at least 3 characters.");
      return;
    }
    if (pass.length < 4) {
      setState(() => _error = "Password must be at least 4 characters.");
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = "Enter a valid email address.");
      return;
    }

    setState(() { _loading = true; _error = null; _regOtpError = null; _alreadyRegistered = false; });
    try {
      final resp = await http.post(
        Uri.parse('${baseUrl()}/auth/register/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': user, 'password': pass, 'email': email}),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        setState(() {
          _regStep       = 1;
          _regOtpSuccess = 'Verification code sent to $email — check your inbox.';
          _regOtpError   = null;
        });
      } else {
        final detail        = body['detail'] ?? 'Failed to send OTP.';
        final isAlreadyReg  = resp.statusCode == 409 &&
            detail.toLowerCase().contains('already registered');
        setState(() {
          _error = detail;
          _alreadyRegistered = isAlreadyReg;
        });
      }
    } catch (e) {
      setState(() { _error = 'Cannot reach server. Is the backend running?'; _alreadyRegistered = false; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* ── PASSWORD tab register: Step 2 — Verify OTP ── */
  Future<void> _verifyRegOtp() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final code  = _regOtpCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _regOtpError = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() { _regOtpLoading = true; _regOtpError = null; });
    try {
      final resp = await http.post(
        Uri.parse('${baseUrl()}/auth/register/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': code}),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        AppSession.token = body['token'];
        AppSession.user  = Map<String, dynamic>.from(body['user']);
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } else {
        setState(() => _regOtpError = body['detail'] ?? 'Invalid OTP.');
      }
    } catch (e) {
      setState(() => _regOtpError = 'Cannot reach server. Is the backend running?');
    } finally {
      if (mounted) setState(() => _regOtpLoading = false);
    }
  }

  /* ── OTP EMAIL tab register: Step 0 — Send OTP to email ── */
  Future<void> _sendRegOtpEmail() async {
    final email = _regOtpEmailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() { _regOtpEmailError = 'Enter a valid email address.'; _regOtpEmailSuccess = null; });
      return;
    }
    setState(() { _regOtpEmailLoading = true; _regOtpEmailError = null; _regOtpEmailSuccess = null; });
    try {
      // We send to the registration OTP endpoint.
      // username = email (temp), password = random — user sets username after via UsernameSetupScreen.
      final resp = await http.post(
        Uri.parse('${baseUrl()}/auth/register/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': email, // temp username = email; user will set real one after
          'password': _generateTempPassword(),
          'email':    email,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        setState(() {
          _regOtpEmailStep    = 1;
          _regOtpEmailSuccess = 'A 6-digit code was sent to $email — check your inbox.';
          _regOtpEmailError   = null;
        });
      } else {
        final detail       = body['detail'] ?? 'Failed to send code.';
        final isAlreadyReg = resp.statusCode == 409 &&
            detail.toLowerCase().contains('already registered');
        setState(() {
          _regOtpEmailError = detail;
          if (isAlreadyReg) {
            _regOtpEmailError = '$detail\n\nHead to the Login page to sign in.';
          }
        });
      }
    } catch (e) {
      setState(() => _regOtpEmailError = 'Cannot reach server. Is the backend running?');
    } finally {
      if (mounted) setState(() => _regOtpEmailLoading = false);
    }
  }

  /* ── OTP EMAIL tab register: Step 1 — Verify OTP → create account → ask username ── */
  Future<void> _verifyRegOtpEmail() async {
    final email = _regOtpEmailCtrl.text.trim().toLowerCase();
    final code  = _regOtpEmailCodeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _regOtpEmailError = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() { _regOtpEmailLoading = true; _regOtpEmailError = null; });
    try {
      final resp = await http.post(
        Uri.parse('${baseUrl()}/auth/register/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': code}),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        AppSession.token = body['token'];
        AppSession.user  = Map<String, dynamic>.from(body['user']);
        if (mounted) {
          // Route to UsernameSetupScreen with fromOtpEmail=true
          // so it collects both username AND password
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => const UsernameSetupScreen(fromOtpEmail: true)));
        }
      } else {
        setState(() => _regOtpEmailError = body['detail'] ?? 'Invalid code.');
      }
    } catch (e) {
      setState(() => _regOtpEmailError = 'Cannot reach server. Is the backend running?');
    } finally {
      if (mounted) setState(() => _regOtpEmailLoading = false);
    }
  }

  String _generateTempPassword() {
    // Random 16-char hex — user registered via OTP email doesn't use password login
    final bytes = List.generate(8, (_) => DateTime.now().microsecondsSinceEpoch & 0xFF);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /* ── Google Sign-In — Web only ── */
  Future<void> _signInWithGoogle() async {
    if (!kIsWeb) return;
    setState(() { _googleLoading = true; _error = null; });
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) { setState(() => _googleLoading = false); return; }
      final auth    = await account.authentication;
      final idToken = auth.idToken ?? auth.accessToken;
      if (idToken == null) {
        setState(() { _error = 'Google returned no token.'; _googleLoading = false; });
        return;
      }
      final resp = await http.post(
        Uri.parse('${baseUrl()}/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        AppSession.token = body['token'];
        AppSession.user  = Map<String, dynamic>.from(body['user']);
        if (mounted) {
          final needsUsername = body['needs_username'] == true;
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => needsUsername
                      ? const UsernameSetupScreen()
                      : const HomeScreen()));
        }
      } else {
        final body = jsonDecode(resp.body);
        setState(() => _error = body['detail'] ?? 'Google login failed.');
      }
    } catch (e) {
      setState(() => _error = 'Google sign-in error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  /* ── Send Login OTP ── */
  Future<void> _sendOtp() async {
    final email = _otpEmailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() { _otpError = 'Enter a valid email address.'; _otpSuccess = null; });
      return;
    }
    setState(() { _otpLoading = true; _otpError = null; _otpSuccess = null; });
    try {
      final endpoint = _isForgotPassword
          ? '${baseUrl()}/auth/send-reset-otp'
          : '${baseUrl()}/auth/send-otp';

      final resp = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        setState(() {
          _otpSent = true;
          _otpSuccess = _isForgotPassword
              ? 'Password reset code sent to $email — check your inbox.'
              : 'Login code sent to $email — check your inbox.';
        });
      } else {
        setState(() => _otpError = body['detail'] ?? 'Failed to send OTP.');
      }
    } catch (e) {
      setState(() => _otpError = 'Cannot reach server. Is the backend running?');
    } finally {
      if (mounted) setState(() => _otpLoading = false);
    }
  }

  /* ── Verify Login OTP ── */
  Future<void> _verifyOtp() async {
    final email = _otpEmailCtrl.text.trim();
    final code  = _otpCodeCtrl.text.trim();
    if (code.length != 6) {
      setState(() { _otpError = 'Enter the 6-digit code from your email.'; });
      return;
    }
    setState(() { _otpLoading = true; _otpError = null; });
    try {
      final resp = await http.post(
        Uri.parse('${baseUrl()}/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': code}),
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        if (_isForgotPassword) {
          setState(() {
            _otpLoading = false;
            _resetStep  = true;
            _otpSuccess = 'OTP verified! Enter your new password below.';
            _otpError   = null;
          });
          return;
        }
        AppSession.token = body['token'];
        AppSession.user  = Map<String, dynamic>.from(body['user']);
        if (mounted) {
          final needsUsername = body['needs_username'] == true;
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => needsUsername
                      ? const UsernameSetupScreen()
                      : const HomeScreen()));
        }
      } else {
        setState(() => _otpError = body['detail'] ?? 'Invalid OTP.');
      }
    } catch (e) {
      setState(() => _otpError = 'Cannot reach server. Is the backend running?');
    } finally {
      if (mounted) setState(() => _otpLoading = false);
    }
  }

  /* ── Reset Password ── */
  Future<void> _resetPassword() async {
    final newPass     = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;
    final email       = _otpEmailCtrl.text.trim().toLowerCase();

    if (newPass.isEmpty || newPass.length < 4) {
      setState(() => _resetError = 'Password must be at least 4 characters.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _resetError = 'Passwords do not match.');
      return;
    }

    setState(() { _otpLoading = true; _resetError = null; });
    try {
      final resp = await http.post(
        Uri.parse('${baseUrl()}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'new_password': newPass}),
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        setState(() {
          _resetSuccess     = 'Password reset! Please login with your new password.';
          _resetStep        = false;
          _isForgotPassword = false;
          _otpSent          = false;
          _otpCodeCtrl.clear();
          _newPassCtrl.clear();
          _confirmPassCtrl.clear();
          _otpSuccess = null;
          _otpError   = null;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _loginTab = 0);
        });
      } else {
        setState(() => _resetError = body['detail'] ?? 'Password reset failed.');
      }
    } catch (e) {
      setState(() => _resetError = 'Cannot reach server. Is the backend running?');
    } finally {
      if (mounted) setState(() => _otpLoading = false);
    }
  }

  /* ── Reset all register OTP email state ── */
  void _resetRegOtpEmailState() {
    _regOtpEmailStep = 0;
    _regOtpEmailCtrl.clear();
    _regOtpEmailCodeCtrl.clear();
    _regOtpEmailError   = null;
    _regOtpEmailSuccess = null;
    _regOtpEmailLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomPaint(
        painter: GridPainter(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: kBorder),
                boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.08),
                    blurRadius: 60, spreadRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Logo ──
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: kGold, borderRadius: BorderRadius.circular(4)),
                      child: const Icon(Icons.photo_camera, color: kBg, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text("HACKX",
                        style: TextStyle(color: kText, fontSize: 22,
                            fontWeight: FontWeight.w800, letterSpacing: 6)),
                  ]),
                  const SizedBox(height: 8),
                  const Text("AI Photo Selector",
                      style: TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.5)),
                  const SizedBox(height: 28),

                  // ── Tabs ──
                  Row(children: [
                    _tabBtn("PASSWORD", 0),
                    const SizedBox(width: 8),
                    _tabBtn("OTP EMAIL", 1),
                  ]),
                  const SizedBox(height: 24),

                  // ══════════════════════════════════════════════════════
                  // REGISTER PAGE
                  // ══════════════════════════════════════════════════════
                  if (_isRegister) ...[

                    // ── REGISTER · PASSWORD TAB ──
                    if (_registerTab == 0) ...[
                      if (_regStep == 0) ...[
                        const SectionLabel("REGISTER"),
                        const SizedBox(height: 20),
                        _buildField("USERNAME", _userCtrl, false),
                        const SizedBox(height: 16),
                        _buildField("EMAIL ADDRESS", _emailCtrl, false),
                        const SizedBox(height: 16),
                        _buildField("PASSWORD", _passCtrl, _obscure,
                            suffix: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                                  color: kMuted, size: 18),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            )),
                        const SizedBox(height: 8),
                        _infoBox(
                          "A verification code will be sent to your email to confirm your account.",
                          Icons.info_outline, kGold,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _errorBox(_error!,
                              loginHint: _alreadyRegistered
                                  ? () => setState(() {
                                        _isRegister = false;
                                        _error = null;
                                        _alreadyRegistered = false;
                                        _emailCtrl.clear();
                                      })
                                  : null),
                        ],
                        const SizedBox(height: 28),
                        _loading
                            ? const Center(child: CircularProgressIndicator(color: kGold))
                            : GoldButton(
                                label: "SEND VERIFICATION CODE",
                                icon: Icons.send,
                                onPressed: _sendRegOtp),
                      ],

                      if (_regStep == 1) ...[
                        const SectionLabel("VERIFY EMAIL"),
                        const SizedBox(height: 16),
                        if (_regOtpSuccess != null)
                          _successBox(_regOtpSuccess!, Icons.mark_email_read),
                        const SizedBox(height: 4),
                        _buildField("6-DIGIT VERIFICATION CODE", _regOtpCtrl, false),
                        if (_regOtpError != null) ...[
                          const SizedBox(height: 12),
                          _errorBox(_regOtpError!),
                        ],
                        const SizedBox(height: 24),
                        _regOtpLoading
                            ? const Center(child: CircularProgressIndicator(color: kGold))
                            : Column(children: [
                                GoldButton(
                                    label: "VERIFY & CREATE ACCOUNT",
                                    icon: Icons.verified,
                                    onPressed: _verifyRegOtp),
                                const SizedBox(height: 10),
                                GoldButton(
                                    label: "RESEND CODE",
                                    outline: true,
                                    icon: Icons.refresh,
                                    onPressed: _resendRegOtp),
                              ]),
                      ],
                    ],

                    // ── REGISTER · OTP EMAIL TAB ──
                    // This is the CORRECT flow: register a NEW account via email OTP
                    // NOT a login flow — completely separate from login OTP tab
                    if (_registerTab == 1) ...[

                      // Step 0: Enter email to register
                      if (_regOtpEmailStep == 0) ...[
                        _stepIndicator(current: 0, total: 2),
                        const SizedBox(height: 16),
                        const SectionLabel("REGISTER WITH EMAIL"),
                        const SizedBox(height: 16),
                        _infoBox(
                          "Enter your email address. We'll send a one-time code to verify "
                          "and create your new account.",
                          Icons.email_outlined, kBlue,
                        ),
                        const SizedBox(height: 16),
                        _buildField("EMAIL ADDRESS", _regOtpEmailCtrl, false),
                        if (_regOtpEmailError != null) ...[
                          const SizedBox(height: 12),
                          _errorBox(_regOtpEmailError!,
                              loginHint: (_regOtpEmailError!.toLowerCase().contains('already registered'))
                                  ? () => setState(() {
                                        _isRegister = false;
                                        _loginTab = 1;
                                        _resetRegOtpEmailState();
                                      })
                                  : null),
                        ],
                        const SizedBox(height: 24),
                        _regOtpEmailLoading
                            ? const Center(child: CircularProgressIndicator(color: kGold))
                            : GoldButton(
                                label: "SEND REGISTRATION CODE",
                                icon: Icons.send,
                                onPressed: _sendRegOtpEmail),
                      ],

                      // Step 1: Enter OTP code to verify email
                      if (_regOtpEmailStep == 1) ...[
                        _stepIndicator(current: 1, total: 2),
                        const SizedBox(height: 16),
                        const SectionLabel("VERIFY YOUR EMAIL"),
                        const SizedBox(height: 16),
                        if (_regOtpEmailSuccess != null)
                          _successBox(_regOtpEmailSuccess!, Icons.mark_email_read),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: kMuted, fontSize: 11,
                                letterSpacing: 0.5, height: 1.6),
                            children: [
                              const TextSpan(text: 'Code sent to '),
                              TextSpan(
                                text: _regOtpEmailCtrl.text.trim(),
                                style: const TextStyle(color: kGold,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildField("6-DIGIT CODE", _regOtpEmailCodeCtrl, false),
                        if (_regOtpEmailError != null) ...[
                          const SizedBox(height: 12),
                          _errorBox(_regOtpEmailError!),
                        ],
                        const SizedBox(height: 24),
                        _regOtpEmailLoading
                            ? const Center(child: CircularProgressIndicator(color: kGold))
                            : Column(children: [
                                GoldButton(
                                    label: "VERIFY & CREATE ACCOUNT",
                                    icon: Icons.verified,
                                    onPressed: _verifyRegOtpEmail),
                                const SizedBox(height: 10),
                                GoldButton(
                                    label: "RESEND CODE",
                                    outline: true,
                                    icon: Icons.refresh,
                                    onPressed: () {
                                      setState(() {
                                        _regOtpEmailStep    = 0;
                                        _regOtpEmailCodeCtrl.clear();
                                        _regOtpEmailError   = null;
                                        _regOtpEmailSuccess = null;
                                      });
                                      _sendRegOtpEmail();
                                    }),
                                const SizedBox(height: 10),
                                // Back to email entry
                                Center(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _regOtpEmailStep    = 0;
                                      _regOtpEmailCodeCtrl.clear();
                                      _regOtpEmailError   = null;
                                      _regOtpEmailSuccess = null;
                                    }),
                                    child: const Text("← CHANGE EMAIL",
                                        style: TextStyle(
                                            color: kMuted, fontSize: 11, letterSpacing: 1)),
                                  ),
                                ),
                              ]),
                      ],
                    ],

                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isRegister = false;
                          _error      = null;
                          _regStep    = 0;
                          _regOtpCtrl.clear();
                          _regOtpError   = null;
                          _regOtpSuccess = null;
                          _emailCtrl.clear();
                          _alreadyRegistered = false;
                          _resetRegOtpEmailState();
                        }),
                        child: const Text(
                          "Already have an account? LOGIN",
                          style: TextStyle(color: kGold, fontSize: 11, letterSpacing: 1.5)),
                      ),
                    ),
                  ],

                  // ══════════════════════════════════════════════════════
                  // LOGIN PAGE
                  // ══════════════════════════════════════════════════════
                  if (!_isRegister) ...[

                    // ── LOGIN · PASSWORD TAB ──
                    if (_loginTab == 0) ...[
                      const SectionLabel("CREDENTIALS"),
                      const SizedBox(height: 20),
                      _buildField("USERNAME", _userCtrl, false),
                      const SizedBox(height: 16),
                      _buildField("PASSWORD", _passCtrl, _obscure,
                          suffix: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                                color: kMuted, size: 18),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          )),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _errorBox(_error!, hint: _showRegisterHint
                            ? () => setState(() {
                                  _isRegister = true;
                                  _error = null;
                                  _showRegisterHint = false;
                                })
                            : null),
                      ],
                      const SizedBox(height: 28),
                      _loading
                          ? const Center(child: CircularProgressIndicator(color: kGold))
                          : GoldButton(
                              label: "ENTER",
                              icon: Icons.arrow_forward,
                              onPressed: _submitLogin),
                      const SizedBox(height: 10),
                      Center(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _loginTab = 1;
                            _isForgotPassword = true;
                            _resetStep = false;
                            _otpSent = false;
                            _otpCodeCtrl.clear();
                            _otpEmailCtrl.clear();
                            _newPassCtrl.clear();
                            _confirmPassCtrl.clear();
                            _otpError   = null;
                            _otpSuccess = null;
                            _resetError = null;
                            _error      = null;
                          }),
                          child: const Text(
                            "Forgot password? RESET VIA EMAIL",
                            style: TextStyle(color: kMuted, fontSize: 11,
                                letterSpacing: 1, decoration: TextDecoration.underline,
                                decorationColor: kMuted),
                          ),
                        ),
                      ),
                    ],

                    // ── LOGIN · OTP EMAIL TAB ──
                    if (_loginTab == 1) ...[
                      SectionLabel(_isForgotPassword ? "RESET PASSWORD" : "EMAIL OTP LOGIN"),
                      const SizedBox(height: 20),

                      if (_isForgotPassword && !_resetStep)
                        _infoBox(
                          "Enter your registered email. A password reset code will be sent.",
                          Icons.lock_reset, kRed,
                        ),

                      if (!_isForgotPassword && !_otpSent)
                        _infoBox(
                          "Enter your registered email. A login code will be sent.",
                          Icons.email_outlined, kBlue,
                        ),

                      if (_resetSuccess != null) ...[
                        const SizedBox(height: 0),
                        _successBox(_resetSuccess!, Icons.check_circle_outline),
                      ],

                      if (_resetStep) ...[
                        if (_otpSuccess != null)
                          _successBox(_otpSuccess!, Icons.verified),
                        _buildField("NEW PASSWORD", _newPassCtrl, _newPassObscure,
                            suffix: IconButton(
                              icon: Icon(_newPassObscure ? Icons.visibility_off : Icons.visibility,
                                  color: kMuted, size: 18),
                              onPressed: () => setState(() => _newPassObscure = !_newPassObscure),
                            )),
                        const SizedBox(height: 16),
                        _buildField("CONFIRM PASSWORD", _confirmPassCtrl, _confirmPassObscure,
                            suffix: IconButton(
                              icon: Icon(_confirmPassObscure ? Icons.visibility_off : Icons.visibility,
                                  color: kMuted, size: 18),
                              onPressed: () => setState(() => _confirmPassObscure = !_confirmPassObscure),
                            )),
                        if (_resetError != null) ...[
                          const SizedBox(height: 12),
                          _errorBox(_resetError!),
                        ],
                        const SizedBox(height: 24),
                        _otpLoading
                            ? const Center(child: CircularProgressIndicator(color: kGold))
                            : GoldButton(
                                label: "SET NEW PASSWORD",
                                icon: Icons.lock_reset,
                                onPressed: _resetPassword),
                      ] else ...[
                        _buildField("EMAIL ADDRESS", _otpEmailCtrl, false),
                        if (_otpSent) ...[
                          const SizedBox(height: 16),
                          _buildField(
                            _isForgotPassword ? "6-DIGIT RESET CODE" : "6-DIGIT LOGIN CODE",
                            _otpCodeCtrl, false,
                          ),
                        ],
                        if (_otpError != null) ...[
                          const SizedBox(height: 12),
                          _errorBox(_otpError!),
                        ],
                        if (_otpSuccess != null && !_resetStep) ...[
                          const SizedBox(height: 12),
                          _successBox(_otpSuccess!, Icons.mark_email_read),
                        ],
                        const SizedBox(height: 28),
                        _otpLoading
                            ? const Center(child: CircularProgressIndicator(color: kGold))
                            : !_otpSent
                                ? GoldButton(
                                    label: _isForgotPassword ? "SEND RESET CODE" : "SEND LOGIN CODE",
                                    icon: Icons.send,
                                    onPressed: _sendOtp)
                                : Column(children: [
                                    GoldButton(
                                      label: _isForgotPassword ? "VERIFY RESET CODE" : "VERIFY & LOGIN",
                                      icon: Icons.verified,
                                      onPressed: _verifyOtp),
                                    const SizedBox(height: 10),
                                    GoldButton(
                                      label: _isForgotPassword ? "RESEND RESET CODE" : "RESEND LOGIN CODE",
                                      outline: true,
                                      icon: Icons.refresh,
                                      onPressed: () async {
                                        setState(() {
                                          _otpCodeCtrl.clear();
                                          _otpError   = null;
                                          _otpSuccess = null;
                                          _otpSent    = false;
                                        });
                                        await _sendOtp();
                                      }),
                                  ]),
                      ],

                      if (_isForgotPassword) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _isForgotPassword = false;
                              _resetStep = false;
                              _otpSent   = false;
                              _otpCodeCtrl.clear();
                              _otpEmailCtrl.clear();
                              _newPassCtrl.clear();
                              _confirmPassCtrl.clear();
                              _otpError     = null;
                              _otpSuccess   = null;
                              _resetError   = null;
                              _resetSuccess = null;
                            }),
                            child: const Text("← BACK TO LOGIN",
                                style: TextStyle(color: kMuted, fontSize: 11, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ],

                    // ── Google + Switch to Register ──
                    const SizedBox(height: 20),
                    if (kIsWeb || (!kIsWeb && (Platform.isAndroid || Platform.isIOS))) ...[
                      Row(children: [
                        Expanded(child: Container(height: 1, color: kBorder)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text("OR", style: TextStyle(color: kMuted, fontSize: 10, letterSpacing: 2)),
                        ),
                        Expanded(child: Container(height: 1, color: kBorder)),
                      ]),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton(
                          onPressed: _googleLoading ? null : _signInWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: _googleLoading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: kGold))
                              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  const Text("G", style: TextStyle(color: Color(0xFF4285F4),
                                      fontSize: 16, fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 10),
                                  const Text("CONTINUE WITH GOOGLE",
                                      style: TextStyle(fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5, color: Colors.black87)),
                                ]),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isRegister = true;
                          _error      = null;
                          _regStep    = 0;
                          _regOtpCtrl.clear();
                          _regOtpError   = null;
                          _regOtpSuccess = null;
                          _emailCtrl.clear();
                          _alreadyRegistered = false;
                          _resetRegOtpEmailState();
                          // Mirror current login tab into register tab
                          _registerTab = _loginTab;
                        }),
                        child: const Text(
                          "No account? REGISTER",
                          style: TextStyle(color: kGold, fontSize: 11, letterSpacing: 1.5)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Center(
                    child: Text("POWERED BY GROQ AI + OPENCV",
                        style: TextStyle(
                            color: kMuted.withValues(alpha: 0.5),
                            fontSize: 9, letterSpacing: 2)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /* ── Tab button — switches loginTab or registerTab depending on mode ── */
  Widget _tabBtn(String label, int index) {
    final active = _isRegister ? (_registerTab == index) : (_loginTab == index);
    final icon   = index == 0 ? Icons.lock_outline : Icons.email_outlined;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_isRegister) {
            _registerTab = index;
            _resetRegOtpEmailState();
            _error = null;
          } else {
            _loginTab = index;
            _error = null;
            _otpError = null;
            _otpSuccess = null;
            _regStep = 0;
            if (index == 0) {
              _isForgotPassword = false;
              _resetStep = false;
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kGold : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? kGold : kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: active ? kBg : kMuted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              color: active ? kBg : kMuted,
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        ]),
      ),
    );
  }

  /* ── Step indicator dots ── */
  Widget _stepIndicator({required int current, required int total}) {
    return Row(
      children: List.generate(total, (i) {
        final isDone   = i < current;
        final isActive = i == current;
        return Container(
          width: 8, height: 8,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone || isActive ? kGold : kBorder,
            boxShadow: isActive
                ? [BoxShadow(color: kGold.withValues(alpha: 0.5), blurRadius: 6)]
                : null,
          ),
        );
      }),
    );
  }

  /* ── Resend OTP for PASSWORD tab register ── */
  Future<void> _resendRegOtp() async {
    setState(() {
      _regOtpCtrl.clear();
      _regOtpError   = null;
      _regOtpSuccess = null;
    });
    final email = _emailCtrl.text.trim().toLowerCase();
    setState(() => _loading = true);
    try {
      final resp = await http.post(
        Uri.parse('${baseUrl()}/auth/register/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _userCtrl.text.trim(),
          'password': _passCtrl.text,
          'email': email
        }),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        setState(() => _regOtpSuccess = 'New code sent to $email — check your inbox.');
      } else {
        setState(() => _regOtpError = body['detail'] ?? 'Failed to resend code.');
      }
    } catch (_) {
      setState(() => _regOtpError = 'Cannot reach server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _infoBox(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(color: color, fontSize: 10, letterSpacing: 0.5)),
        ),
      ]),
    );
  }

  Widget _successBox(String msg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: kGreen.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(icon, color: kGreen, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(msg,
            style: const TextStyle(color: kGreen, fontSize: 11))),
      ]),
    );
  }

  Widget _errorBox(String msg, {VoidCallback? hint, VoidCallback? loginHint}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: kRed.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.error_outline, color: kRed, size: 14),
          const SizedBox(width: 6),
          Expanded(child: Text(msg,
              style: const TextStyle(color: kRed, fontSize: 11, letterSpacing: 0.5))),
        ]),
        if (hint != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: hint,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: kGold),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_add, color: kGold, size: 13),
                SizedBox(width: 6),
                Text("TAP HERE TO REGISTER",
                    style: TextStyle(color: kGold, fontSize: 10,
                        letterSpacing: 1.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
        if (loginHint != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: loginHint,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: kGold),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.login, color: kGold, size: 13),
                SizedBox(width: 6),
                Text("TAP HERE TO LOGIN",
                    style: TextStyle(color: kGold, fontSize: 10,
                        letterSpacing: 1.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool obscure,
      {Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: kMuted, fontSize: 10, letterSpacing: 2.5)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(color: kText, fontSize: 14),
          onSubmitted: (_) {
            if (!_isRegister && _loginTab == 0) _submitLogin();
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: kCard,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: kGold, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

/* ═══════════════════════════════════════════════════════════════════════
   2. USERNAME SETUP SCREEN
   - fromOtpEmail=true  → came from OTP EMAIL register: ask username + password
   - fromOtpEmail=false → came from Google sign-in: ask username only (skip allowed)
═══════════════════════════════════════════════════════════════════════ */
class UsernameSetupScreen extends StatefulWidget {
  /// Set to true when arriving from OTP EMAIL registration.
  /// Will show both username AND password fields.
  final bool fromOtpEmail;
  const UsernameSetupScreen({super.key, this.fromOtpEmail = false});
  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _usernameCtrl    = TextEditingController();
  final _passCtrl        = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass      = true;
  bool _obscureConfirm   = true;
  bool _loading          = false;
  String? _error;

  Future<void> _save() async {
    final name = _usernameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = "Please enter a username.");
      return;
    }
    if (name.length < 3) {
      setState(() => _error = "Username must be at least 3 characters.");
      return;
    }

    // Extra validation when password is required (OTP email flow)
    if (widget.fromOtpEmail) {
      final pass    = _passCtrl.text;
      final confirm = _confirmPassCtrl.text;
      if (pass.length < 4) {
        setState(() => _error = "Password must be at least 4 characters.");
        return;
      }
      if (pass != confirm) {
        setState(() => _error = "Passwords do not match.");
        return;
      }
    }

    setState(() { _loading = true; _error = null; });
    try {
      // 1. Set username
      final usernameResp = await http.post(
        Uri.parse('${baseUrl()}/auth/set-username'),
        headers: AppSession.authHeaders,
        body: jsonEncode({'username': name}),
      ).timeout(const Duration(seconds: 10));

      final usernameBody = jsonDecode(usernameResp.body);
      if (usernameResp.statusCode != 200) {
        setState(() => _error = usernameBody['detail'] ?? 'Failed to set username.');
        return;
      }
      AppSession.user?['username'] = usernameBody['username'];

      // 2. If OTP email flow, also update the password via reset-password endpoint
      if (widget.fromOtpEmail) {
        final email = AppSession.user?['email'] ?? '';
        final passResp = await http.post(
          Uri.parse('${baseUrl()}/auth/set-password'),
          headers: AppSession.authHeaders,
          body: jsonEncode({'email': email, 'new_password': _passCtrl.text}),
        ).timeout(const Duration(seconds: 10));

        if (passResp.statusCode != 200) {
          final passBody = jsonDecode(passResp.body);
          setState(() => _error = passBody['detail'] ?? 'Failed to set password.');
          return;
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      setState(() => _error = 'Cannot reach server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _skip() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  Widget _field(String label, TextEditingController ctrl, bool obscure,
      {Widget? suffix, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: kMuted, fontSize: 10, letterSpacing: 2.5)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(color: kText, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: kCard,
            hintText: hint,
            hintStyle: const TextStyle(color: kBorder, fontSize: 12),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: kGold, width: 1.5)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomPaint(
        painter: GridPainter(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: kBorder),
                boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.08),
                    blurRadius: 60, spreadRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Logo ──
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: kGold, borderRadius: BorderRadius.circular(4)),
                      child: const Icon(Icons.photo_camera, color: kBg, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text("HACKX",
                        style: TextStyle(color: kText, fontSize: 22,
                            fontWeight: FontWeight.w800, letterSpacing: 6)),
                  ]),
                  const SizedBox(height: 8),
                  const Text("Set up your profile",
                      style: TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.5)),
                  const SizedBox(height: 28),

                  // ── Success banner ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: kGreen.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: kGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle, color: kGreen, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Account created! 🎉\nSigned in as ${AppSession.user?['email'] ?? 'user'}",
                          style: const TextStyle(color: kGreen, fontSize: 11,
                              height: 1.6, letterSpacing: 0.5),
                        ),
                      ),
                    ]),
                  ),

                  // ── Section label changes based on mode ──
                  SectionLabel(widget.fromOtpEmail
                      ? "COMPLETE YOUR PROFILE"
                      : "CHOOSE A USERNAME"),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: kGold.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: kGold.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.person_outline, color: kGold, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.fromOtpEmail
                              ? "Set a username and password so you can also log in with them later."
                              : "Pick a display username, or skip to use your email as your username.",
                          style: const TextStyle(
                              color: kGold, fontSize: 10, letterSpacing: 0.5),
                        ),
                      ),
                    ]),
                  ),

                  // ── Username field ──
                  _field("USERNAME", _usernameCtrl, false,
                      hint: "e.g. coolphotographer42"),

                  // ── Password fields — only for OTP email registration ──
                  if (widget.fromOtpEmail) ...[
                    const SizedBox(height: 16),
                    _field("PASSWORD", _passCtrl, _obscurePass,
                        hint: "At least 4 characters",
                        suffix: IconButton(
                          icon: Icon(_obscurePass
                              ? Icons.visibility_off : Icons.visibility,
                              color: kMuted, size: 18),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        )),
                    const SizedBox(height: 16),
                    _field("CONFIRM PASSWORD", _confirmPassCtrl, _obscureConfirm,
                        hint: "Re-enter password",
                        suffix: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_off : Icons.visibility,
                              color: kMuted, size: 18),
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        )),
                  ],

                  // ── Error box ──
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: kRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: kRed, size: 14),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_error!,
                            style: const TextStyle(color: kRed, fontSize: 11))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 28),
                  _loading
                      ? const Center(child: CircularProgressIndicator(color: kGold))
                      : Column(children: [
                          GoldButton(
                              label: widget.fromOtpEmail
                                  ? "SAVE & CONTINUE"
                                  : "SET USERNAME",
                              icon: Icons.check,
                              onPressed: _save),
                          const SizedBox(height: 10),
                          // Only Google flow gets a skip — OTP email flow must set password
                          if (!widget.fromOtpEmail)
                            GoldButton(
                                label: "SKIP FOR NOW",
                                outline: true,
                                icon: Icons.arrow_forward,
                                onPressed: _skip),
                        ]),

                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      widget.fromOtpEmail
                          ? "You can change your username & password later in settings."
                          : "You can change your username later in settings.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: kMuted.withValues(alpha: 0.5),
                          fontSize: 9, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════════════════
   3. HOME SCREEN
═══════════════════════════════════════════════════════════════════════ */
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _folders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      final resp = await http.get(
        Uri.parse('${baseUrl()}/folders'),
        headers: AppSession.authHeaders,
      );
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        setState(() { _folders = data.cast<Map<String, dynamic>>(); });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _deleteFolder(int id, String folderName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: Text('Delete "$folderName"?',
            style: const TextStyle(color: kRed, fontSize: 13)),
        content: const Text("All photos in this folder will also be removed.",
            style: TextStyle(color: kMuted, fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text("CANCEL", style: TextStyle(color: kMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text("DELETE", style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok != true) return;
    await http.delete(Uri.parse('${baseUrl()}/folders/$id'),
        headers: AppSession.authHeaders);
    _loadFolders();
  }

  void _logout() async {
    try {
      if (kIsWeb || (!kIsWeb && (Platform.isAndroid || Platform.isIOS))) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}

    try {
      await http.post(
        Uri.parse('${baseUrl()}/auth/logout'),
        headers: AppSession.authHeaders,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}

    AppSession.token = null;
    AppSession.user  = null;

    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  static bool _isAutoFolder(String name) => name.startsWith('[S');

  Color _sessionFolderColor(String name) {
    if (name.contains('Excellent')) return const Color(0xFF00E676);
    if (name.contains('Great'))     return kGreen;
    if (name.contains('Good'))      return kGold;
    if (name.contains('Average') && !name.contains('Below')) return const Color(0xFFFF9800);
    if (name.contains('Below'))     return const Color(0xFFFF5722);
    if (name.contains('Poor'))      return kRed;
    return kMuted;
  }

  @override
  Widget build(BuildContext context) {
    final autoList   = _folders.where((f) => _isAutoFolder(f['name'])).toList();
    final manualList = _folders.where((f) => !_isAutoFolder(f['name'])).toList();

    final Map<String, List<Map<String, dynamic>>> sessions = {};
    for (final f in autoList) {
      final match = RegExp(r'\[([^\]]+)\]').firstMatch(f['name']);
      final key   = match?.group(1) ?? 'Session';
      sessions.putIfAbsent(key, () => []).add(f);
    }
    final sessionKeys = sessions.keys.toList().reversed.toList();

    return Scaffold(
      backgroundColor: kBg,
      appBar: buildAppBar(
        "HACKX  ·  ${AppSession.user?['username'] ?? ''}",
        actions: [
          IconButton(
              icon: const Icon(Icons.logout, color: kMuted),
              tooltip: "Logout",
              onPressed: _logout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GoldButton(
                      label: "UPLOAD & ANALYZE",
                      icon: Icons.auto_awesome,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const UploadScreen(folderId: null)),
                      ).then((_) => _loadFolders()),
                    ),
                  ),

                  if (sessionKeys.isNotEmpty) ...[
                    const Divider(color: kBorder, height: 1),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: SectionLabel("ANALYSIS RESULTS"),
                    ),
                    ...sessionKeys.map((sessionKey) {
                      final folders = sessions[sessionKey]!;
                      const order = ['Excellent','Great','Good','Average','Below','Poor'];
                      folders.sort((a, b) {
                        int ai = order.indexWhere((o) => a['name'].contains(o));
                        int bi = order.indexWhere((o) => b['name'].contains(o));
                        return ai.compareTo(bi);
                      });

                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: kBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: kGold.withValues(alpha: 0.08),
                                borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(6)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.analytics_outlined,
                                    color: kGold, size: 14),
                                const SizedBox(width: 8),
                                Text(sessionKey,
                                    style: const TextStyle(
                                        color: kGold, fontSize: 12,
                                        fontWeight: FontWeight.w700, letterSpacing: 1)),
                                const Spacer(),
                                Text("${folders.length} folders",
                                    style: const TextStyle(color: kMuted, fontSize: 10)),
                              ]),
                            ),
                            ...folders.map((f) {
                              final color       = _sessionFolderColor(f['name']);
                              final displayName = f['name']
                                  .replaceFirst(RegExp(r'\[[^\]]+\]\s*'), '');
                              return InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FolderPhotosScreen(folder: f),
                                  ),
                                ).then((_) => _loadFolders()),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(top: BorderSide(color: kBorder)),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 6, height: 6,
                                      decoration: BoxDecoration(
                                          color: color, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(displayName,
                                          style: TextStyle(
                                              color: color, fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    Icon(Icons.chevron_right,
                                        color: color.withValues(alpha: 0.6), size: 16),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: kMuted, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _deleteFolder(f['id'], f['name']),
                                    ),
                                  ]),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],

                  if (manualList.isNotEmpty) ...[
                    const Divider(color: kBorder, height: 1),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: SectionLabel("MY FOLDERS"),
                    ),
                    ...manualList.map((f) => Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              leading: const Icon(Icons.folder, color: kGold),
                              title: Text(f['name'],
                                  style: const TextStyle(
                                      color: kText, letterSpacing: 1.5, fontSize: 13)),
                              subtitle: Text(f['created_at'] ?? '',
                                  style: const TextStyle(color: kMuted, fontSize: 10)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: kMuted, size: 20),
                                onPressed: () => _deleteFolder(f['id'], f['name']),
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FolderPhotosScreen(folder: f),
                                ),
                              ).then((_) => _loadFolders()),
                            ),
                            const Divider(color: kBorder, height: 1),
                          ],
                        )),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════════════════
   4. FOLDER PHOTOS SCREEN
═══════════════════════════════════════════════════════════════════════ */
class FolderPhotosScreen extends StatefulWidget {
  final Map<String, dynamic> folder;
  const FolderPhotosScreen({super.key, required this.folder});
  @override
  State<FolderPhotosScreen> createState() => _FolderPhotosScreenState();
}

class _FolderPhotosScreenState extends State<FolderPhotosScreen> {
  List<Map<String, dynamic>> _photos = [];
  bool _loading = true;
  bool _gridView = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final resp = await http.get(
      Uri.parse('${baseUrl()}/photos?folder_id=${widget.folder['id']}'),
      headers: AppSession.authHeaders,
    );
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      setState(() => _photos = data.cast<Map<String, dynamic>>());
    }
    setState(() => _loading = false);
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text("Delete photo?",
            style: TextStyle(color: kRed, fontSize: 13)),
        content: Text(photo['filename'] ?? '',
            style: const TextStyle(color: kMuted, fontSize: 11)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("CANCEL", style: TextStyle(color: kMuted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("DELETE", style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (confirmed != true) return;
    final resp = await http.delete(
      Uri.parse('${baseUrl()}/photos/${photo['id']}'),
      headers: AppSession.authHeaders,
    );
    if (resp.statusCode == 200) _load();
  }

  Color _scoreColor(double s) {
    if (s >= 90) return const Color(0xFF00E676);
    if (s >= 80) return kGreen;
    if (s >= 70) return kGold;
    if (s >= 60) return const Color(0xFFFF9800);
    if (s >= 50) return const Color(0xFFFF5722);
    return kRed;
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
      itemCount: _photos.length,
      itemBuilder: (_, i) {
        final p          = _photos[i];
        final score      = (p['score'] as num).toDouble();
        final isPrecious = p['is_precious'] == 1;
        final showDelete = score < 65 && !isPrecious;
        final path       = p['filepath'] as String?;

        return GestureDetector(
          onTap: () => _showPhotoDetail(p),
          child: Stack(
            fit: StackFit.expand,
            children: [
              (!kIsWeb && path != null && File(path).existsSync())
                  ? Image.file(File(path), fit: BoxFit.cover)
                  : Container(
                      color: kSurface,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image, color: kMuted, size: 28),
                          const SizedBox(height: 4),
                          Text(
                            p['filename'] ?? '',
                            style: const TextStyle(color: kMuted, fontSize: 7),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )),
              Positioned(
                bottom: 4, left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(score.toStringAsFixed(0),
                      style: TextStyle(
                          color: _scoreColor(score),
                          fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              ),
              if (isPrecious)
                const Positioned(
                  top: 4, left: 4,
                  child: Icon(Icons.favorite, color: kGold, size: 14,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                ),
              if (showDelete)
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => _deletePhoto(p),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                          color: kRed.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(2)),
                      child: const Icon(Icons.delete, color: Colors.white, size: 12),
                    ),
                  ),
                ),
              if (score >= 90)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFF00E676).withValues(alpha: 0.6),
                        width: 2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _photos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p          = _photos[i];
        final score      = (p['score'] as num).toDouble();
        final isPrecious = p['is_precious'] == 1;
        final showDelete = score < 65 && !isPrecious;
        final path       = p['filepath'] as String?;

        return GestureDetector(
          onTap: () => _showPhotoDetail(p),
          child: Container(
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: score >= 90
                      ? const Color(0xFF00E676).withValues(alpha: 0.4)
                      : kBorder),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
                  child: (!kIsWeb && path != null && File(path).existsSync())
                      ? Image.file(File(path), width: 80, height: 80, fit: BoxFit.cover)
                      : Container(
                          width: 80, height: 80,
                          color: kSurface,
                          child: const Icon(Icons.image, color: kMuted, size: 28)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (isPrecious)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.favorite, color: kGold, size: 12),
                          ),
                        Expanded(
                          child: Text(p['filename'] ?? '',
                              style: const TextStyle(
                                  color: kText, fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      if ((p['caption'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.auto_awesome, color: kGold, size: 10),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(p['caption'],
                                style: const TextStyle(
                                    color: kMuted, fontSize: 10,
                                    fontStyle: FontStyle.italic),
                                overflow: TextOverflow.ellipsis, maxLines: 2),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 6),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _scoreColor(score).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: _scoreColor(score).withValues(alpha: 0.4)),
                          ),
                          child: Text("${score.toStringAsFixed(1)} / 100",
                              style: TextStyle(
                                  color: _scoreColor(score),
                                  fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                        if (showDelete) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: kRed.withValues(alpha: 0.15),
                              border: Border.all(color: kRed.withValues(alpha: 0.4)),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Text("LOW QUALITY",
                                style: TextStyle(color: kRed, fontSize: 8, letterSpacing: 1)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: score / 100,
                          backgroundColor: kBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(_scoreColor(score)),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showDelete)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: kRed),
                      onPressed: () => _deletePhoto(p),
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPhotoDetail(Map<String, dynamic> p) {
    final path = p['filepath'] as String?;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4), topRight: Radius.circular(4)),
              child: (!kIsWeb && path != null && File(path).existsSync())
                  ? Image.file(File(path),
                      width: double.infinity, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200, color: kSurface,
                        child: const Center(
                          child: Icon(Icons.image_not_supported, color: kMuted, size: 48)),
                      ))
                  : Container(
                      height: 200, color: kSurface,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image, color: kMuted, size: 48),
                            const SizedBox(height: 8),
                            Text(p['filename'] ?? '',
                                style: const TextStyle(color: kMuted, fontSize: 11),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      )),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['filename'] ?? '',
                      style: const TextStyle(
                          color: kText, fontSize: 13, fontWeight: FontWeight.w700)),
                  if ((p['caption'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.auto_awesome, color: kGold, size: 12),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(p['caption'],
                            style: const TextStyle(
                                color: kMuted, fontSize: 11, fontStyle: FontStyle.italic)),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 10),
                  Text("Score: ${(p['score'] as num).toStringAsFixed(1)} / 100",
                      style: TextStyle(
                          color: _scoreColor((p['score'] as num).toDouble()),
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("CLOSE",
                        style: TextStyle(color: kGold, letterSpacing: 2)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: buildAppBar(
        widget.folder['name'].toString().toUpperCase(),
        showBack: true,
        onBack: () => Navigator.pop(context),
        actions: [
          IconButton(
            icon: Icon(_gridView ? Icons.view_list : Icons.grid_view, color: kGold),
            tooltip: _gridView ? "List view" : "Grid view",
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : _photos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo_library_outlined, color: kMuted, size: 48),
                      const SizedBox(height: 12),
                      const Text("NO PHOTOS IN THIS FOLDER",
                          style: TextStyle(color: kMuted, fontSize: 12, letterSpacing: 2)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      color: kSurface,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.photo, color: kGold, size: 14),
                        const SizedBox(width: 6),
                        Text("${_photos.length} PHOTOS",
                            style: const TextStyle(color: kText, fontSize: 11, letterSpacing: 1.5)),
                        const SizedBox(width: 16),
                        const Icon(Icons.emoji_events, color: kGold, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          "BEST: ${_photos.map((p) => (p['score'] as num).toDouble()).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)}",
                          style: const TextStyle(color: kText, fontSize: 11, letterSpacing: 1.5),
                        ),
                      ]),
                    ),
                    const Divider(color: kBorder, height: 1),
                    Expanded(child: _gridView ? _buildGrid() : _buildList()),
                  ],
                ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════════════════
   5. UPLOAD SCREEN
═══════════════════════════════════════════════════════════════════════ */
class UploadScreen extends StatefulWidget {
  final int? folderId;
  const UploadScreen({super.key, this.folderId});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<XFile> selectedImages    = [];
  List<Uint8List> selectedBytes = [];
  final Set<int> _preciousIndexes = {};
  final ImagePicker picker = ImagePicker();

  Future<void> pickImages() async {
    List<XFile> picked = [];

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      picked = await picker.pickMultiImage();
    } else {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, allowMultiple: true, withData: true);
      if (result != null) {
        picked = result.files.map((f) => XFile.fromData(f.bytes!, name: f.name)).toList();
      }
    }

    if (picked.isEmpty) return;

    final List<Uint8List> bytes = [];
    for (final img in picked) {
      bytes.add(await img.readAsBytes());
    }

    setState(() {
      selectedImages = picked;
      selectedBytes  = bytes;
      _preciousIndexes.clear();
    });
  }

  void _togglePrecious(int i) {
    setState(() {
      if (_preciousIndexes.contains(i)) {
        _preciousIndexes.remove(i);
      } else {
        _preciousIndexes.add(i);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final preciousCount = _preciousIndexes.length;

    return Scaffold(
      backgroundColor: kBg,
      appBar: buildAppBar(
        widget.folderId != null ? "UPLOAD TO FOLDER" : "UPLOAD & ANALYZE",
        showBack: true,
        onBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          Container(
            color: kGold.withValues(alpha: 0.07),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: const Row(
              children: [
                Icon(Icons.favorite, color: kGold, size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "TAP a photo to mark it as PRECIOUS  ·  precious photos never show a delete icon",
                    style: TextStyle(color: kGold, fontSize: 10, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.photo_library, color: kGold, size: 14),
                const SizedBox(width: 6),
                Text("${selectedImages.length} SELECTED",
                    style: const TextStyle(color: kText, fontSize: 11, letterSpacing: 1.5)),
                if (preciousCount > 0) ...[
                  const SizedBox(width: 14),
                  const Icon(Icons.favorite, color: kGold, size: 13),
                  const SizedBox(width: 4),
                  Text("$preciousCount PRECIOUS",
                      style: const TextStyle(color: kGold, fontSize: 11, letterSpacing: 1.5)),
                ],
                const Spacer(),
                if (selectedImages.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() {
                      selectedImages = [];
                      selectedBytes  = [];
                      _preciousIndexes.clear();
                    }),
                    child: const Text("CLEAR ALL",
                        style: TextStyle(color: kMuted, fontSize: 10, letterSpacing: 2)),
                  ),
              ],
            ),
          ),
          const Divider(color: kBorder, height: 1),
          Expanded(
            child: selectedImages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                              border: Border.all(color: kBorder, width: 1.5),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.add_photo_alternate,
                              color: kMuted, size: 36),
                        ),
                        const SizedBox(height: 20),
                        const Text("NO PHOTOS SELECTED",
                            style: TextStyle(
                                color: kMuted, fontSize: 12, letterSpacing: 3)),
                        const SizedBox(height: 8),
                        const Text("Tap SELECT PHOTOS to begin",
                            style: TextStyle(color: kBorder, fontSize: 11)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4),
                    itemCount: selectedImages.length,
                    itemBuilder: (_, i) {
                      final isPrecious = _preciousIndexes.contains(i);
                      final bytes      = selectedBytes.length > i ? selectedBytes[i] : null;

                      return GestureDetector(
                        onTap: () => _togglePrecious(i),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            bytes != null
                                ? Image.memory(bytes, fit: BoxFit.cover)
                                : Container(color: kSurface,
                                    child: const Icon(Icons.image, color: kMuted)),
                            if (isPrecious)
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: kGold, width: 3),
                                  color: kGold.withValues(alpha: 0.15),
                                ),
                              ),
                            Positioned(
                              bottom: 6, left: 6,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: isPrecious
                                    ? const Icon(Icons.favorite,
                                        key: ValueKey('on'),
                                        color: kGold, size: 20,
                                        shadows: [Shadow(color: Colors.black, blurRadius: 4)])
                                    : const Icon(Icons.favorite_border,
                                        key: ValueKey('off'),
                                        color: Colors.white54, size: 18),
                              ),
                            ),
                            if (isPrecious)
                              Positioned(
                                top: 6, left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kGold,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Text("PRECIOUS",
                                      style: TextStyle(
                                          color: kBg, fontSize: 7,
                                          fontWeight: FontWeight.w800, letterSpacing: 1)),
                                ),
                              ),
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  selectedImages.removeAt(i);
                                  if (i < selectedBytes.length) selectedBytes.removeAt(i);
                                  final updated = <int>{};
                                  for (final idx in _preciousIndexes) {
                                    if (idx < i) updated.add(idx);
                                    if (idx > i) updated.add(idx - 1);
                                  }
                                  _preciousIndexes..clear()..addAll(updated);
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: kText, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            color: kSurface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GoldButton(
                    label: "SELECT PHOTOS",
                    outline: true,
                    icon: Icons.add_photo_alternate,
                    onPressed: pickImages),
                const SizedBox(height: 10),
                GoldButton(
                  label: "ANALYZE & RANK",
                  icon: Icons.auto_awesome,
                  onPressed: selectedImages.isEmpty
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProcessingScreen(
                                images: selectedImages,
                                imageBytes: List.from(selectedBytes),
                                preciousIndexes: Set.from(_preciousIndexes),
                                folderId: widget.folderId,
                              ),
                            ),
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════════════════
   6. PROCESSING SCREEN
═══════════════════════════════════════════════════════════════════════ */
class ProcessingScreen extends StatefulWidget {
  final List<XFile> images;
  final List<Uint8List> imageBytes;
  final int? folderId;
  final Set<int> preciousIndexes;
  const ProcessingScreen({
    super.key,
    required this.images,
    required this.imageBytes,
    this.folderId,
    this.preciousIndexes = const {},
  });
  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  List<Map<String, dynamic>> results = [];
  String? error;
  bool _showBreakdown = false;

  @override
  void initState() {
    super.initState();
    _uploadImages();
  }

  Future<void> _uploadImages() async {
    try {
      final preciousParam = widget.preciousIndexes.join(',');

      final uri = Uri.parse('${baseUrl()}/upload-images').replace(
        queryParameters: {
          if (widget.folderId != null) 'folder_id': widget.folderId.toString(),
          if (preciousParam.isNotEmpty) 'precious_indexes': preciousParam,
        },
      );

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer ${AppSession.token ?? ""}';

      for (int i = 0; i < widget.images.length; i++) {
        final bytes    = widget.imageBytes.length > i
            ? widget.imageBytes[i]
            : await widget.images[i].readAsBytes();
        final filename = widget.images[i].name;
        request.files.add(
            http.MultipartFile.fromBytes('files', bytes, filename: filename));
      }

      final response = await request.send();
      final body     = jsonDecode(await response.stream.bytesToString());
      List<Map<String, dynamic>> sorted =
          List<Map<String, dynamic>>.from(body['results']);
      sorted.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
      if (mounted) setState(() => results = sorted);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Uint8List? _findBytes(String filename) {
    final idx = widget.images.indexWhere((img) => img.name == filename);
    if (idx < 0 || idx >= widget.imageBytes.length) return null;
    return widget.imageBytes[idx];
  }

  Color _scoreColor(double score) {
    if (score >= 70) return kGreen;
    if (score >= 45) return kGold;
    return kRed;
  }

  Color _folderColor(String folderName) {
    if (folderName.contains('Excellent'))                                    return const Color(0xFF00E676);
    if (folderName.contains('Great'))                                        return kGreen;
    if (folderName.contains('Good') && !folderName.contains('Below'))       return kGold;
    if (folderName.contains('Average') && !folderName.contains('Below'))    return const Color(0xFFFF9800);
    if (folderName.contains('Below'))                                        return const Color(0xFFFF5722);
    if (folderName.contains('Poor'))                                         return kRed;
    return kMuted;
  }

  String _scoreLabel(double score) {
    if (score >= 70) return "EXCELLENT";
    if (score >= 50) return "GOOD";
    if (score >= 30) return "FAIR";
    return "POOR";
  }

  Widget _breakdownWidget(Map<String, dynamic> bd) {
    final metrics = [
      ("BLUR",     (bd['blur']        ?? 0.0) as num, 30.0, kBlue),
      ("BRIGHT",   (bd['brightness']  ?? 0.0) as num, 20.0, kGold),
      ("CONTRAST", (bd['contrast']    ?? 0.0) as num, 20.0, kGold),
      ("NOISE",    (bd['noise']       ?? 0.0) as num, 10.0, kGreen),
      ("COMPOSE",  (bd['composition'] ?? 0.0) as num,  5.0, kGreen),
      ("FACE",     (bd['face']        ?? 0.0) as num, 20.0, kRed),
      ("RES",      (bd['resolution']  ?? 0.0) as num,  5.0, kBlue),
      ("COLOR",    (bd['color']       ?? 0.0) as num,  5.0, kGold),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8, right: 12),
      child: Column(
        children: metrics
            .map((m) => BreakdownBar(
                  label: m.$1,
                  value: m.$2.toDouble(),
                  max: m.$3,
                  color: m.$4))
            .toList(),
      ),
    );
  }

  Future<void> _tryDelete(Map<String, dynamic> item) async {
    if (item['precious'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: kCard,
        content: Text("Precious photo — delete blocked. Unmark precious first to delete.",
            style: TextStyle(color: kGold, fontSize: 11)),
      ));
      return;
    }
    final id = item['id'];
    if (id == null) return;
    final resp = await http.delete(
      Uri.parse('${baseUrl()}/photos/$id'),
      headers: AppSession.authHeaders,
    );
    if (resp.statusCode == 200 && mounted) {
      setState(() => results.removeWhere((r) => r['id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: kCard,
        content: Text("Photo deleted.", style: TextStyle(color: kRed, fontSize: 11)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: buildAppBar(
        "RANKED RESULTS",
        showBack: true,
        onBack: () => Navigator.pop(context),
        actions: [
          if (results.isNotEmpty)
            IconButton(
              icon: Icon(_showBreakdown ? Icons.bar_chart : Icons.bar_chart_outlined,
                  color: kGold),
              tooltip: "Toggle score breakdown",
              onPressed: () => setState(() => _showBreakdown = !_showBreakdown),
            ),
        ],
      ),
      body: error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: kRed, size: 48),
                  const SizedBox(height: 16),
                  const Text("CONNECTION FAILED",
                      style: TextStyle(color: kText, fontSize: 13, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  const Text("Is the backend running on port 8000?",
                      style: TextStyle(color: kMuted, fontSize: 11)),
                ],
              ),
            )
          : results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 48, height: 48,
                        child: CircularProgressIndicator(
                            color: kGold, strokeWidth: 2,
                            backgroundColor: kGold.withValues(alpha: 0.1)),
                      ),
                      const SizedBox(height: 24),
                      const Text("ANALYZING PHOTOS",
                          style: TextStyle(
                              color: kText, fontSize: 13, letterSpacing: 3)),
                      const SizedBox(height: 8),
                      const Text(
                          "Scoring sharpness, brightness, faces + AI captions...",
                          style: TextStyle(color: kMuted, fontSize: 11)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      color: kSurface,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.photo, color: kGold, size: 14),
                          const SizedBox(width: 6),
                          Text("${results.length} PHOTOS",
                              style: const TextStyle(
                                  color: kText, fontSize: 11, letterSpacing: 1.5)),
                          const SizedBox(width: 20),
                          const Icon(Icons.emoji_events, color: kGold, size: 14),
                          const SizedBox(width: 6),
                          Text("BEST: ${results.first['score']}",
                              style: const TextStyle(
                                  color: kText, fontSize: 11, letterSpacing: 1.5)),
                          if (widget.preciousIndexes.isNotEmpty) ...[
                            const Spacer(),
                            const Icon(Icons.favorite, color: kGold, size: 14),
                            const SizedBox(width: 4),
                            const Text("PRECIOUS",
                                style: TextStyle(
                                    color: kGold, fontSize: 10, letterSpacing: 1.5)),
                          ],
                        ],
                      ),
                    ),
                    const Divider(color: kBorder, height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final item       = results[index];
                          final bytes      = _findBytes(item['filename']);
                          final score      = (item['score'] as num).toDouble();
                          final bd         = (item['breakdown'] as Map<String, dynamic>?) ?? {};
                          final isPrecious = item['precious'] == true;
                          final showDelete = item['show_delete'] == true;

                          return Container(
                            decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: index == 0
                                      ? kGold.withValues(alpha: 0.5) : kBorder),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: index == 0 ? kGold : kSurface,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4),
                                          bottomLeft: Radius.circular(4),
                                        ),
                                      ),
                                      child: Text("#${index + 1}",
                                          style: TextStyle(
                                              color: index == 0 ? kBg : kMuted,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13)),
                                    ),
                                    bytes != null
                                        ? Image.memory(bytes,
                                            width: 70, height: 70, fit: BoxFit.cover)
                                        : Container(
                                            width: 70, height: 70,
                                            color: kSurface,
                                            child: const Icon(Icons.image,
                                                color: kMuted, size: 28)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            if (isPrecious)
                                              const Padding(
                                                padding: EdgeInsets.only(right: 4),
                                                child: Icon(Icons.favorite,
                                                    color: kGold, size: 12),
                                              ),
                                            Expanded(
                                              child: Text(item['filename'],
                                                  style: const TextStyle(
                                                      color: kText, fontSize: 11,
                                                      fontWeight: FontWeight.w600),
                                                  overflow: TextOverflow.ellipsis),
                                            ),
                                          ]),
                                          if ((item['caption'] ?? '').isNotEmpty) ...[
                                            const SizedBox(height: 5),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 7, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: kSurface,
                                                borderRadius: BorderRadius.circular(3),
                                                border: Border.all(
                                                    color: kGold.withValues(alpha: 0.2)),
                                              ),
                                              child: Row(children: [
                                                const Icon(Icons.auto_awesome,
                                                    color: kGold, size: 10),
                                                const SizedBox(width: 5),
                                                Expanded(
                                                  child: Text(item['caption'],
                                                      style: const TextStyle(
                                                          color: kText, fontSize: 10,
                                                          fontStyle: FontStyle.italic),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 2),
                                                ),
                                              ]),
                                            ),
                                          ],
                                          if ((item['folder'] ?? '').isNotEmpty) ...[
                                            const SizedBox(height: 5),
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.popUntil(
                                                    context, (r) => r.isFirst);
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: _folderColor(item['folder'])
                                                      .withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(3),
                                                  border: Border.all(
                                                      color: _folderColor(item['folder'])
                                                          .withValues(alpha: 0.5)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.folder,
                                                        color: _folderColor(item['folder']),
                                                        size: 10),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(item['folder'],
                                                          style: TextStyle(
                                                              color: _folderColor(item['folder']),
                                                              fontSize: 9,
                                                              letterSpacing: 0.5,
                                                              fontWeight: FontWeight.w600),
                                                          overflow: TextOverflow.ellipsis),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Icon(Icons.open_in_new,
                                                        color: _folderColor(item['folder']),
                                                        size: 8),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _scoreColor(score)
                                                      .withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(2),
                                                  border: Border.all(
                                                      color: _scoreColor(score)
                                                          .withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                    _scoreLabel(score),
                                                    style: TextStyle(
                                                        color: _scoreColor(score),
                                                        fontSize: 9,
                                                        letterSpacing: 1.5,
                                                        fontWeight: FontWeight.w700)),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                  "${score.toStringAsFixed(1)} / 100",
                                                  style: const TextStyle(
                                                      color: kMuted, fontSize: 11)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(2),
                                            child: LinearProgressIndicator(
                                              value: score / 100,
                                              backgroundColor: kBorder,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      _scoreColor(score)),
                                              minHeight: 3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(6, 10, 10, 4),
                                          child: GestureDetector(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => EnhancingScreen(
                                                  imageBytes: bytes,
                                                  filename: item['filename'],
                                                  enhanceUrl: '${baseUrl()}/enhance-image',
                                                  analyzeUrl: '${baseUrl()}/analyze-image',
                                                ),
                                              ),
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 7),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: kGold),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: const Column(children: [
                                                Icon(Icons.auto_fix_high,
                                                    color: kGold, size: 16),
                                                SizedBox(height: 3),
                                                Text("FIX",
                                                    style: TextStyle(
                                                        color: kGold, fontSize: 9,
                                                        letterSpacing: 1.5,
                                                        fontWeight: FontWeight.w700)),
                                              ]),
                                            ),
                                          ),
                                        ),
                                        if (showDelete)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(6, 0, 10, 6),
                                            child: GestureDetector(
                                              onTap: () => _tryDelete(item),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 7),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: kRed.withValues(alpha: 0.6)),
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                                child: const Column(children: [
                                                  Icon(Icons.delete_outline,
                                                      color: kRed, size: 16),
                                                  SizedBox(height: 3),
                                                  Text("DEL",
                                                      style: TextStyle(
                                                          color: kRed, fontSize: 9,
                                                          letterSpacing: 1.5,
                                                          fontWeight: FontWeight.w700)),
                                                ]),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (_showBreakdown && bd.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(44 + 70.0 + 14, 0, 0, 4),
                                    child: _breakdownWidget(bd),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════════════════
   7. ENHANCING SCREEN
═══════════════════════════════════════════════════════════════════════ */
class EnhancingScreen extends StatefulWidget {
  final Uint8List? imageBytes;
  final String filename;
  final String enhanceUrl;
  final String analyzeUrl;
  const EnhancingScreen({
    super.key,
    required this.imageBytes,
    required this.filename,
    required this.enhanceUrl,
    required this.analyzeUrl,
  });
  @override
  State<EnhancingScreen> createState() => _EnhancingScreenState();
}

class _EnhancingScreenState extends State<EnhancingScreen> {
  Uint8List? enhancedBytes;
  Map<String, dynamic>? analysis;
  String? enhanceError;
  String method = "";
  bool loadingAnalysis = true;
  bool _saving = false;
  String _viewMode = 'side';

  @override
  void initState() {
    super.initState();
    enhance();
    analyzeWithGroq();
  }

  Future<void> enhance() async {
    try {
      final bytes = widget.imageBytes;
      if (bytes == null) throw Exception('No image data');
      var request = http.MultipartRequest('POST', Uri.parse(widget.enhanceUrl));
      request.headers['Authorization'] = 'Bearer ${AppSession.token ?? ""}';
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: widget.filename));
      final response =
          await request.send().timeout(const Duration(seconds: 45));
      final body = jsonDecode(await response.stream.bytesToString());
      if (body['enhanced'] == null) throw Exception('No enhanced data returned');
      if (mounted) {
        setState(() {
          enhancedBytes = base64Decode(body['enhanced'] as String);
          method = body['method'] == 'ai' ? 'AI ENHANCED — GROQ' : 'ENHANCED — OPENCV';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            enhanceError = e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> analyzeWithGroq() async {
    try {
      final bytes = widget.imageBytes;
      if (bytes == null) throw Exception('No image data');
      var request = http.MultipartRequest('POST', Uri.parse(widget.analyzeUrl));
      request.headers['Authorization'] = 'Bearer ${AppSession.token ?? ""}';
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: widget.filename));
      final response =
          await request.send().timeout(const Duration(seconds: 45));
      final body = jsonDecode(await response.stream.bytesToString());
      if (mounted) {
        setState(() {
          analysis       = body['analysis'];
          loadingAnalysis = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loadingAnalysis = false);
    }
  }

  Future<void> _saveImage() async {
    if (enhancedBytes == null) return;
    setState(() => _saving = true);
    try {
      final filename =
          'hackx_enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Enhanced Image',
          fileName: filename,
          type: FileType.image,
          allowedExtensions: ['jpg'],
        );
        if (savePath == null) { if (mounted) setState(() => _saving = false); return; }
        await File(savePath).writeAsBytes(enhancedBytes!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: kCard,
            content: Text('Saved: $savePath',
                style: const TextStyle(color: kGold, fontSize: 11)),
          ));
        }
      } else if (!kIsWeb) {
        final savePath = Platform.isAndroid
            ? '/storage/emulated/0/Download/$filename'
            : '${Directory.systemTemp.path}/$filename';
        await File(savePath).writeAsBytes(enhancedBytes!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: kCard,
            content: Text('Saved to $savePath',
                style: const TextStyle(color: kGold, fontSize: 11)),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kRed,
          content: Text('Save failed: $e',
              style: const TextStyle(color: kText, fontSize: 11)),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Widget> _buildList(String title, List items, Color color) => [
        Text(title,
            style: TextStyle(
                color: color, fontSize: 10,
                letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, color: color, size: 6),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(item.toString(),
                          style: const TextStyle(color: kText, fontSize: 12))),
                ],
              ),
            )),
        const SizedBox(height: 10),
      ];

  Widget _imgBox(Widget child, {BorderRadius? radius}) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: radius ?? BorderRadius.circular(4),
        border: Border.all(color: kBorder),
      ),
      child: ClipRRect(
        borderRadius: radius ?? BorderRadius.circular(4),
        child: child,
      ),
    );
  }

  Widget _loadingOrError() {
    if (enhanceError != null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kRed.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: kRed, size: 24),
            const SizedBox(height: 6),
            const Text("ENHANCEMENT FAILED",
                style: TextStyle(color: kRed, fontSize: 10, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(enhanceError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kMuted, fontSize: 9)),
            ),
          ],
        ),
      );
    }
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kBorder)),
      child: const CircularProgressIndicator(color: kGold, strokeWidth: 2),
    );
  }

  Widget _origWidget() {
    final bytes = widget.imageBytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.contain, width: double.infinity);
    }
    return Container(height: 200, color: kSurface,
        child: const Center(child: Icon(Icons.image, color: kMuted, size: 48)));
  }

  Widget _buildSideBySide() {
    Widget enhImg = enhancedBytes != null
        ? Image.memory(enhancedBytes!, fit: BoxFit.contain, width: double.infinity)
        : SizedBox(height: 140, child: _loadingOrError());

    return Container(
      decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(children: [
                    ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4)),
                        child: _origWidget()),
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(2)),
                        child: const Text("ORIGINAL",
                            style: TextStyle(color: kMuted, fontSize: 8, letterSpacing: 1.5)),
                      ),
                    ),
                  ]),
                ),
                Container(width: 2, color: kGold),
                Expanded(
                  child: Stack(children: [
                    ClipRRect(
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(4)),
                        child: enhImg),
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(2)),
                        child: const Text("ENHANCED",
                            style: TextStyle(color: kGold, fontSize: 8, letterSpacing: 1.5)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          if (method.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: 0.07),
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
              ),
              child: Center(
                child: Text(method,
                    style: const TextStyle(color: kGold, fontSize: 9, letterSpacing: 1.5)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullStacked() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel("ORIGINAL"),
        const SizedBox(height: 8),
        _imgBox(_origWidget()),
        const SizedBox(height: 20),
        Row(children: [
          const SectionLabel("ENHANCED"),
          const Spacer(),
          if (method.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: 0.1),
                border: Border.all(color: kGold.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(method,
                  style: const TextStyle(color: kGold, fontSize: 9, letterSpacing: 1.5)),
            ),
        ]),
        const SizedBox(height: 8),
        enhancedBytes != null
            ? _imgBox(Image.memory(enhancedBytes!, width: double.infinity, fit: BoxFit.contain))
            : _loadingOrError(),
      ],
    );
  }

  Widget _viewToggle() {
    return GestureDetector(
      onTap: () => setState(
          () => _viewMode = _viewMode == 'side' ? 'full' : 'side'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(3)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _viewMode == 'side' ? Icons.view_agenda_outlined : Icons.compare,
              color: kMuted, size: 12,
            ),
            const SizedBox(width: 5),
            Text(
              _viewMode == 'side' ? "FULL VIEW" : "SIDE BY SIDE",
              style: const TextStyle(color: kMuted, fontSize: 9, letterSpacing: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: buildAppBar("ENHANCEMENT",
          showBack: true,
          onBack: () => Navigator.pop(context),
          actions: [
            IconButton(
              icon: Icon(
                _viewMode == 'side' ? Icons.view_agenda_outlined : Icons.compare,
                color: kGold,
              ),
              tooltip: _viewMode == 'side' ? "Full view" : "Side by side",
              onPressed: () => setState(
                  () => _viewMode = _viewMode == 'side' ? 'full' : 'side'),
            ),
            if (enhancedBytes != null)
              _saving
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: kGold, strokeWidth: 2)))
                  : IconButton(
                      icon: const Icon(Icons.save_alt, color: kGold),
                      tooltip: "Save enhanced image",
                      onPressed: _saveImage,
                    ),
          ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              SectionLabel(_viewMode == 'side' ? "COMPARE" : "FULL VIEW"),
              const Spacer(),
              _viewToggle(),
            ]),
            const SizedBox(height: 10),
            _viewMode == 'side' ? _buildSideBySide() : _buildFullStacked(),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: kGold.withValues(alpha: 0.4)),
              ),
              child: loadingAnalysis
                  ? const Row(children: [
                      SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: kGold, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text("GROQ ANALYZING...",
                          style: TextStyle(
                              color: kGold, fontSize: 11, letterSpacing: 2)),
                    ])
                  : analysis == null
                      ? const Text("Analysis unavailable",
                          style: TextStyle(color: kMuted))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.auto_awesome, color: kGold, size: 14),
                              SizedBox(width: 8),
                              Text("GROQ AI ANALYSIS",
                                  style: TextStyle(
                                      color: kGold, fontSize: 11,
                                      letterSpacing: 2, fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 12),
                            Text(analysis!['overall'] ?? '',
                                style: const TextStyle(color: kText, fontSize: 13)),
                            const SizedBox(height: 14),
                            if ((analysis!['strengths'] as List).isNotEmpty)
                              ..._buildList(
                                  "STRENGTHS", analysis!['strengths'], kGreen),
                            if ((analysis!['issues'] as List).isNotEmpty)
                              ..._buildList("ISSUES", analysis!['issues'], kRed),
                            if (analysis!['tip'] != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: kGold.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(3)),
                                child: Row(children: [
                                  const Icon(Icons.lightbulb_outline,
                                      color: kGold, size: 14),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(analysis!['tip'],
                                          style: const TextStyle(
                                              color: kGold, fontSize: 11))),
                                ]),
                              ),
                            ],
                          ],
                        ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}