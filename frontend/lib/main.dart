import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const PhotoSelectorApp());
}

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
String baseUrl() => Platform.isAndroid
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
   1. LOGIN SCREEN  — real API auth with token session
═══════════════════════════════════════════════════════════════════════ */
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _isRegister = false;
  bool _showRegisterHint = false;
  String? _error;

  Future<void> _submit() async {
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
      final endpoint = _isRegister ? '/auth/register' : '/auth/login';
      final resp = await http.post(
        Uri.parse('${baseUrl()}$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': user, 'password': pass}),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final body = jsonDecode(resp.body);
        AppSession.token = body['token'];
        AppSession.user  = Map<String, dynamic>.from(body['user']);
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } else {
        final body = jsonDecode(resp.body);
        final detail = body['detail'] ?? 'Something went wrong.';

        // If not registered and tried to login → offer to switch to register
        if (resp.statusCode == 404 && !_isRegister) {
          setState(() {
            _error = detail;
            _showRegisterHint = true;
          });
        } else {
          setState(() {
            _error = detail;
            _showRegisterHint = false;
          });
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
                  const SizedBox(height: 40),
                  SectionLabel(_isRegister ? "REGISTER" : "CREDENTIALS"),
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: kRed.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.error_outline, color: kRed, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: kRed, fontSize: 11, letterSpacing: 0.5)),
                            ),
                          ]),
                          if (_showRegisterHint) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => setState(() {
                                _isRegister = true;
                                _error = null;
                                _showRegisterHint = false;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: kGold.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: kGold),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_add, color: kGold, size: 13),
                                    SizedBox(width: 6),
                                    Text("TAP HERE TO REGISTER",
                                        style: TextStyle(
                                            color: kGold, fontSize: 10,
                                            letterSpacing: 1.5,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _loading
                      ? const Center(child: CircularProgressIndicator(color: kGold))
                      : GoldButton(
                          label: _isRegister ? "REGISTER" : "ENTER",
                          icon: Icons.arrow_forward,
                          onPressed: _submit),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isRegister = !_isRegister;
                        _error = null;
                      }),
                      child: Text(
                        _isRegister
                            ? "Already have an account? LOGIN"
                            : "No account? REGISTER",
                        style: const TextStyle(
                            color: kGold, fontSize: 11, letterSpacing: 1.5)),
                    ),
                  ),
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
          onSubmitted: (_) => _submit(),
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
   2. HOME SCREEN — folder list + nav to upload
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

  Future<void> _createFolder() async {
    String? name;
    await showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: kCard,
          title: const Text("NEW FOLDER",
              style: TextStyle(color: kGold, letterSpacing: 2, fontSize: 13)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: kText),
            decoration: const InputDecoration(
              hintText: "Folder name",
              hintStyle: TextStyle(color: kMuted),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: kBorder)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: kGold)),
            ),
            onSubmitted: (v) { name = v; Navigator.pop(ctx); },
          ),
          actions: [
            TextButton(
              onPressed: () { name = ctrl.text; Navigator.pop(ctx); },
              child: const Text("CREATE",
                  style: TextStyle(color: kGold, letterSpacing: 1.5)),
            ),
          ],
        );
      },
    );
    if (name == null || name!.trim().isEmpty) return;
    final resp = await http.post(
      Uri.parse('${baseUrl()}/folders'),
      headers: AppSession.authHeaders,
      body: jsonEncode({'name': name!.trim()}),
    );
    if (resp.statusCode == 200) _loadFolders();
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

  void _logout() {
    http.post(Uri.parse('${baseUrl()}/auth/logout'),
        headers: AppSession.authHeaders);
    AppSession.token = null;
    AppSession.user  = null;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  // Auto folders now start with "[S" prefix e.g. "[S1 · 02 Mar 03:19]"
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

    // Group auto folders by session prefix e.g. "S1 · 02 Mar 03:19"
    final Map<String, List<Map<String, dynamic>>> sessions = {};
    for (final f in autoList) {
      // Extract session key from "[S1 · 02 Mar 03:19] 🏆 Excellent"
      final match = RegExp(r'\[([^\]]+)\]').firstMatch(f['name']);
      final key = match?.group(1) ?? 'Session';
      sessions.putIfAbsent(key, () => []).add(f);
    }
    // Sort sessions so newest is first
    final sessionKeys = sessions.keys.toList().reversed.toList();

    return Scaffold(
      backgroundColor: kBg,
      appBar: buildAppBar(
        "HACKX  ·  ${AppSession.user?['username'] ?? ''}",
        actions: [
          IconButton(
              icon: const Icon(Icons.add_box_outlined, color: kGold),
              tooltip: "New folder",
              onPressed: _createFolder),
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

                  // ── UPLOAD button ──────────────────────────────────
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

                  // ══════════════════════════════════════════════════
                  // ANALYSIS SESSIONS — each run is a separate group
                  // ══════════════════════════════════════════════════
                  if (sessionKeys.isNotEmpty) ...[
                    const Divider(color: kBorder, height: 1),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: SectionLabel("ANALYSIS RESULTS"),
                    ),
                    ...sessionKeys.map((sessionKey) {
                      final folders = sessions[sessionKey]!;
                      // Sort within session: Excellent→Poor
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
                            // Session header
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
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1)),
                                const Spacer(),
                                Text("${folders.length} folders",
                                    style: const TextStyle(
                                        color: kMuted, fontSize: 10)),
                              ]),
                            ),
                            // Sub-folders
                            ...folders.map((f) {
                              final color = _sessionFolderColor(f['name']);
                              // Show just the grade part after "] "
                              final displayName = f['name']
                                  .replaceFirst(RegExp(r'\[[^\]]+\]\s*'), '');
                              return InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FolderPhotosScreen(folder: f),
                                  ),
                                ).then((_) => _loadFolders()),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                        top: BorderSide(color: kBorder)),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 6, height: 6,
                                      decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(displayName,
                                          style: TextStyle(
                                              color: color,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    Icon(Icons.chevron_right,
                                        color: color.withValues(alpha: 0.6),
                                        size: 16),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: kMuted, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () =>
                                          _deleteFolder(f['id'], f['name']),
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

                  // ══════════════════════════════════════════════════
                  // MY FOLDERS (manual)
                  // ══════════════════════════════════════════════════
                  const Divider(color: kBorder, height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(children: [
                      const SectionLabel("MY FOLDERS"),
                      const Spacer(),
                      GestureDetector(
                        onTap: _createFolder,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: kGold),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, color: kGold, size: 13),
                              SizedBox(width: 4),
                              Text("NEW",
                                  style: TextStyle(
                                      color: kGold, fontSize: 10,
                                      letterSpacing: 1.5)),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),

                  if (manualList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text("No folders yet — tap NEW to create one",
                            style: TextStyle(color: kMuted, fontSize: 11)),
                      ),
                    )
                  else
                    ...manualList.map((f) => Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              leading: const Icon(Icons.folder, color: kGold),
                              title: Text(f['name'],
                                  style: const TextStyle(
                                      color: kText, letterSpacing: 1.5,
                                      fontSize: 13)),
                              subtitle: Text(f['created_at'] ?? '',
                                  style: const TextStyle(
                                      color: kMuted, fontSize: 10)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.add_photo_alternate,
                                        color: kGold, size: 20),
                                    tooltip: "Upload here",
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            UploadScreen(folderId: f['id']),
                                      ),
                                    ).then((_) => _loadFolders()),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: kMuted, size: 20),
                                    onPressed: () =>
                                        _deleteFolder(f['id'], f['name']),
                                  ),
                                ],
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FolderPhotosScreen(folder: f),
                                ),
                              ).then((_) => _loadFolders()),
                            ),
                            const Divider(color: kBorder, height: 1),
                          ],
                        )),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════════════════
   3. FOLDER PHOTOS SCREEN — grid + list view with thumbnails
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
  bool _gridView = true; // toggle between grid and list

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
        final p = _photos[i];
        final score = (p['score'] as num).toDouble();
        final isPrecious = p['is_precious'] == 1;
        final showDelete = score < 65 && !isPrecious;
        final path = p['filepath'] as String?;

        return GestureDetector(
          onTap: () => _showPhotoDetail(p),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              path != null && File(path).existsSync()
                  ? Image.file(File(path), fit: BoxFit.cover)
                  : Container(
                      color: kSurface,
                      child: const Icon(Icons.image_not_supported,
                          color: kMuted, size: 32)),

              // Score badge bottom-left
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

              // Precious heart
              if (isPrecious)
                const Positioned(
                  top: 4, left: 4,
                  child: Icon(Icons.favorite, color: kGold, size: 14,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                ),

              // Delete overlay
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

              // Gold border if excellent
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
        final p = _photos[i];
        final score = (p['score'] as num).toDouble();
        final isPrecious = p['is_precious'] == 1;
        final showDelete = score < 65 && !isPrecious;
        final path = p['filepath'] as String?;

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
                // Thumbnail
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4)),
                  child: path != null && File(path).existsSync()
                      ? Image.file(File(path),
                          width: 80, height: 80, fit: BoxFit.cover)
                      : Container(
                          width: 80, height: 80,
                          color: kSurface,
                          child: const Icon(Icons.image_not_supported,
                              color: kMuted, size: 28)),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filename + precious
                      Row(children: [
                        if (isPrecious)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.favorite, color: kGold, size: 12),
                          ),
                        Expanded(
                          child: Text(p['filename'] ?? '',
                              style: const TextStyle(
                                  color: kText, fontSize: 12,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),

                      // Caption
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
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2),
                          ),
                        ]),
                      ],

                      const SizedBox(height: 6),

                      // Score bar
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _scoreColor(score).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                                color: _scoreColor(score).withValues(alpha: 0.4)),
                          ),
                          child: Text("${score.toStringAsFixed(1)} / 100",
                              style: TextStyle(
                                  color: _scoreColor(score),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (showDelete) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: kRed.withValues(alpha: 0.15),
                              border: Border.all(
                                  color: kRed.withValues(alpha: 0.4)),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Text("LOW QUALITY",
                                style: TextStyle(
                                    color: kRed, fontSize: 8,
                                    letterSpacing: 1)),
                          ),
                        ],
                      ]),

                      // Progress bar
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: score / 100,
                          backgroundColor: kBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              _scoreColor(score)),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete button
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
            // Full image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4), topRight: Radius.circular(4)),
              child: path != null && File(path).existsSync()
                  ? Image.file(File(path),
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: kSurface,
                        child: const Center(
                          child: Icon(Icons.image_not_supported,
                              color: kMuted, size: 48)),
                      ))
                  : Container(
                      height: 200, color: kSurface,
                      child: const Center(
                        child: Icon(Icons.image_not_supported,
                            color: kMuted, size: 48))),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['filename'] ?? '',
                      style: const TextStyle(
                          color: kText, fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  if ((p['caption'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.auto_awesome, color: kGold, size: 12),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(p['caption'],
                            style: const TextStyle(
                                color: kMuted, fontSize: 11,
                                fontStyle: FontStyle.italic)),
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
          // Toggle grid/list
          IconButton(
            icon: Icon(
              _gridView ? Icons.view_list : Icons.grid_view,
              color: kGold,
            ),
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
                      const Icon(Icons.photo_library_outlined,
                          color: kMuted, size: 48),
                      const SizedBox(height: 12),
                      const Text("NO PHOTOS IN THIS FOLDER",
                          style: TextStyle(
                              color: kMuted, fontSize: 12, letterSpacing: 2)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Stats bar
                    Container(
                      color: kSurface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.photo, color: kGold, size: 14),
                        const SizedBox(width: 6),
                        Text("${_photos.length} PHOTOS",
                            style: const TextStyle(
                                color: kText, fontSize: 11, letterSpacing: 1.5)),
                        const SizedBox(width: 16),
                        const Icon(Icons.emoji_events, color: kGold, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          "BEST: ${_photos.map((p) => (p['score'] as num).toDouble()).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)}",
                          style: const TextStyle(
                              color: kText, fontSize: 11, letterSpacing: 1.5),
                        ),
                      ]),
                    ),
                    const Divider(color: kBorder, height: 1),
                    Expanded(
                      child: _gridView ? _buildGrid() : _buildList(),
                    ),
                  ],
                ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════════════════
   4. UPLOAD SCREEN — pick images, mark precious, choose folder
═══════════════════════════════════════════════════════════════════════ */
class UploadScreen extends StatefulWidget {
  final int? folderId;
  const UploadScreen({super.key, this.folderId});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<XFile> selectedImages = [];
  // Per-photo precious set — stores index of precious photos
  final Set<int> _preciousIndexes = {};
  final ImagePicker picker = ImagePicker();

  Future<void> pickImages() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final images = await picker.pickMultiImage();
      setState(() {
        selectedImages = images;
        _preciousIndexes.clear();
      });
    } else {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, allowMultiple: true);
      if (result != null) {
        setState(() {
          selectedImages =
              result.paths.whereType<String>().map((p) => XFile(p)).toList();
          _preciousIndexes.clear();
        });
      }
    }
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
        widget.folderId != null ? "UPLOAD TO FOLDER" : "UPLOAD — ROOT",
        showBack: true,
        onBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          // ── Info bar ──
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
          // ── Count bar ──
          Container(
            color: kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.photo_library, color: kGold, size: 14),
                const SizedBox(width: 6),
                Text("${selectedImages.length} SELECTED",
                    style: const TextStyle(
                        color: kText, fontSize: 11, letterSpacing: 1.5)),
                if (preciousCount > 0) ...[
                  const SizedBox(width: 14),
                  const Icon(Icons.favorite, color: kGold, size: 13),
                  const SizedBox(width: 4),
                  Text("$preciousCount PRECIOUS",
                      style: const TextStyle(
                          color: kGold, fontSize: 11, letterSpacing: 1.5)),
                ],
                const Spacer(),
                if (selectedImages.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() {
                      selectedImages = [];
                      _preciousIndexes.clear();
                    }),
                    child: const Text("CLEAR ALL",
                        style: TextStyle(
                            color: kMuted, fontSize: 10, letterSpacing: 2)),
                  ),
              ],
            ),
          ),
          const Divider(color: kBorder, height: 1),

          // ── Grid ──
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
                      return GestureDetector(
                        // ── TAP = toggle precious ──
                        onTap: () => _togglePrecious(i),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Photo
                            Image.file(File(selectedImages[i].path),
                                fit: BoxFit.cover),

                            // Precious overlay — gold tint + heart
                            if (isPrecious)
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: kGold, width: 3),
                                  color: kGold.withValues(alpha: 0.15),
                                ),
                              ),

                            // Heart icon (bottom-left)
                            Positioned(
                              bottom: 6, left: 6,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: isPrecious
                                    ? const Icon(Icons.favorite,
                                        key: ValueKey('on'),
                                        color: kGold, size: 20,
                                        shadows: [Shadow(
                                          color: Colors.black,
                                          blurRadius: 4)])
                                    : const Icon(Icons.favorite_border,
                                        key: ValueKey('off'),
                                        color: Colors.white54, size: 18),
                              ),
                            ),

                            // PRECIOUS label (top-left)
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
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1)),
                                ),
                              ),

                            // Remove button (top-right)
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  selectedImages.removeAt(i);
                                  // Re-map precious indexes after removal
                                  final updated = <int>{};
                                  for (final idx in _preciousIndexes) {
                                    if (idx < i) updated.add(idx);
                                    if (idx > i) updated.add(idx - 1);
                                  }
                                  _preciousIndexes
                                    ..clear()
                                    ..addAll(updated);
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      color: kText, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ── Bottom buttons ──
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
   5. PROCESSING SCREEN — analyze, caption, rank, precious-delete guard
═══════════════════════════════════════════════════════════════════════ */
class ProcessingScreen extends StatefulWidget {
  final List<XFile> images;
  final int? folderId;
  final Set<int> preciousIndexes;
  const ProcessingScreen({
    super.key,
    required this.images,
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
      // Build precious_indexes query param
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
        request.files.add(
            await http.MultipartFile.fromPath('files', widget.images[i].path));
      }

      final response = await request.send();
      final body = jsonDecode(await response.stream.bytesToString());
      List<Map<String, dynamic>> sorted =
          List<Map<String, dynamic>>.from(body['results']);
      sorted.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
      if (mounted) setState(() => results = sorted);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  XFile _findImage(String filename) =>
      widget.images.firstWhere((img) => img.name == filename);

  Color _scoreColor(double score) {
    if (score >= 70) return kGreen;
    if (score >= 45) return kGold;
    return kRed;
  }

  Color _folderColor(String folderName) {
    if (folderName.contains('Excellent'))                    return const Color(0xFF00E676);
    if (folderName.contains('Great'))                        return kGreen;
    if (folderName.contains('Good') && !folderName.contains('Below')) return kGold;
    if (folderName.contains('Average') && !folderName.contains('Below')) return const Color(0xFFFF9800);
    if (folderName.contains('Below'))                        return const Color(0xFFFF5722);
    if (folderName.contains('Poor'))                         return kRed;
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

  /* ── Precious-aware delete ── */
  Future<void> _tryDelete(Map<String, dynamic> item) async {
    if (item['precious'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: kCard,
        content: Text("Precious photo — delete blocked. "
            "Unmark precious first to delete.",
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
        content: Text("Photo deleted.",
            style: TextStyle(color: kRed, fontSize: 11)),
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
              icon: Icon(
                  _showBreakdown ? Icons.bar_chart : Icons.bar_chart_outlined,
                  color: kGold),
              tooltip: "Toggle score breakdown",
              onPressed: () =>
                  setState(() => _showBreakdown = !_showBreakdown),
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
                      style:
                          TextStyle(color: kText, fontSize: 13, letterSpacing: 2)),
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
                            backgroundColor:
                                kGold.withValues(alpha: 0.1)),
                      ),
                      const SizedBox(height: 24),
                      const Text("ANALYZING PHOTOS",
                          style: TextStyle(
                              color: kText, fontSize: 13, letterSpacing: 3)),
                      const SizedBox(height: 8),
                      const Text(
                          "Scoring sharpness, brightness, faces + AI captions...",
                          style:
                              TextStyle(color: kMuted, fontSize: 11)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // ── Summary bar ──
                    Container(
                      color: kSurface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
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

                    // ── Results list ──
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final item  = results[index];
                          final img   = _findImage(item['filename']);
                          final score = (item['score'] as num).toDouble();
                          final bd    = (item['breakdown']
                                  as Map<String, dynamic>?) ??
                              {};
                          final isPrecious = item['precious'] == true;
                          final showDelete = item['show_delete'] == true;

                          return Container(
                            decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: index == 0
                                      ? kGold.withValues(alpha: 0.5)
                                      : kBorder),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // ── Rank badge ──
                                    Container(
                                      width: 44,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      decoration: BoxDecoration(
                                        color: index == 0 ? kGold : kSurface,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4),
                                          bottomLeft: Radius.circular(4),
                                        ),
                                      ),
                                      child: Text("#${index + 1}",
                                          style: TextStyle(
                                              color: index == 0
                                                  ? kBg : kMuted,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13)),
                                    ),
                                    // ── Thumbnail ──
                                    ClipRRect(
                                      child: Image.file(
                                          File(img.path),
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover),
                                    ),
                                    const SizedBox(width: 14),
                                    // ── Info ──
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Filename + precious icon
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

                                          // ── AI Caption — prominent ──
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
                                                          color: kText,
                                                          fontSize: 10,
                                                          fontStyle: FontStyle.italic),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 2),
                                                ),
                                              ]),
                                            ),
                                          ],

                                          // ── Folder chip — tappable ──
                                          if ((item['folder'] ?? '').isNotEmpty) ...[
                                            const SizedBox(height: 5),
                                            GestureDetector(
                                              onTap: () {
                                                // Navigate to folder on home screen
                                                Navigator.popUntil(context,
                                                    (r) => r.isFirst);
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
                                                              color: _folderColor(
                                                                  item['folder']),
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
                                          // Score badge
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _scoreColor(score)
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(2),
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
                                    // ── Action buttons ──
                                    Column(
                                      children: [
                                        // FIX button
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              6, 10, 10, 4),
                                          child: GestureDetector(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => EnhancingScreen(
                                                  img: img,
                                                  enhanceUrl:
                                                      '${baseUrl()}/enhance-image',
                                                  analyzeUrl:
                                                      '${baseUrl()}/analyze-image',
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
                                        // ── DELETE icon (score < 65, not precious) ──
                                        if (showDelete)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                6, 0, 10, 6),
                                            child: GestureDetector(
                                              onTap: () => _tryDelete(item),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 7),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: kRed
                                                          .withValues(alpha: 0.6)),
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                                child: const Column(children: [
                                                  Icon(Icons.delete_outline,
                                                      color: kRed, size: 16),
                                                  SizedBox(height: 3),
                                                  Text("DEL",
                                                      style: TextStyle(
                                                          color: kRed, fontSize: 9,
                                                          letterSpacing: 1.5,
                                                          fontWeight:
                                                              FontWeight.w700)),
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
                                    padding: const EdgeInsets.fromLTRB(
                                        44 + 70.0 + 14, 0, 0, 4),
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
   ENHANCING SCREEN  — unchanged logic, auth header added
═══════════════════════════════════════════════════════════════════════ */
class EnhancingScreen extends StatefulWidget {
  final XFile img;
  final String enhanceUrl;
  final String analyzeUrl;
  const EnhancingScreen({
    super.key,
    required this.img,
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
      final bytes = await File(widget.img.path).readAsBytes();
      var request = http.MultipartRequest('POST', Uri.parse(widget.enhanceUrl));
      request.headers['Authorization'] = 'Bearer ${AppSession.token ?? ""}';
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: widget.img.name));
      final response =
          await request.send().timeout(const Duration(seconds: 45));
      final body = jsonDecode(await response.stream.bytesToString());
      if (body['enhanced'] == null) throw Exception('No enhanced data returned');
      if (mounted) {
        setState(() {
          enhancedBytes = base64Decode(body['enhanced'] as String);
          method = body['method'] == 'ai'
              ? 'AI ENHANCED — GROQ' : 'ENHANCED — OPENCV';
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
      final bytes = await File(widget.img.path).readAsBytes();
      var request = http.MultipartRequest('POST', Uri.parse(widget.analyzeUrl));
      request.headers['Authorization'] = 'Bearer ${AppSession.token ?? ""}';
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: widget.img.name));
      final response =
          await request.send().timeout(const Duration(seconds: 45));
      final body = jsonDecode(await response.stream.bytesToString());
      if (mounted) {
        setState(() {
          analysis = body['analysis'];
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
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Enhanced Image',
          fileName: filename,
          type: FileType.image,
          allowedExtensions: ['jpg'],
        );
        if (savePath == null) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        await File(savePath).writeAsBytes(enhancedBytes!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: kCard,
            content: Text('Saved: $savePath',
                style: const TextStyle(color: kGold, fontSize: 11)),
          ));
        }
      } else {
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
                          style: const TextStyle(
                              color: kText, fontSize: 12))),
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
                style: TextStyle(
                    color: kRed, fontSize: 10, letterSpacing: 1.5)),
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

  Widget _buildSideBySide() {
    Widget origImg = Image.file(File(widget.img.path),
        fit: BoxFit.contain, width: double.infinity);
    Widget enhImg = enhancedBytes != null
        ? Image.memory(enhancedBytes!,
            fit: BoxFit.contain, width: double.infinity)
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
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4)),
                        child: origImg),
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(2)),
                        child: const Text("ORIGINAL",
                            style: TextStyle(
                                color: kMuted, fontSize: 8, letterSpacing: 1.5)),
                      ),
                    ),
                  ]),
                ),
                Container(width: 2, color: kGold),
                Expanded(
                  child: Stack(children: [
                    ClipRRect(
                        borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(4)),
                        child: enhImg),
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(2)),
                        child: const Text("ENHANCED",
                            style: TextStyle(
                                color: kGold, fontSize: 8, letterSpacing: 1.5)),
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
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4)),
              ),
              child: Center(
                child: Text(method,
                    style: const TextStyle(
                        color: kGold, fontSize: 9, letterSpacing: 1.5)),
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
        _imgBox(Image.file(File(widget.img.path),
            width: double.infinity, fit: BoxFit.contain)),
        const SizedBox(height: 20),
        Row(children: [
          const SectionLabel("ENHANCED"),
          const Spacer(),
          if (method.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: 0.1),
                border:
                    Border.all(color: kGold.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(method,
                  style: const TextStyle(
                      color: kGold, fontSize: 9, letterSpacing: 1.5)),
            ),
        ]),
        const SizedBox(height: 8),
        enhancedBytes != null
            ? _imgBox(Image.memory(enhancedBytes!,
                width: double.infinity, fit: BoxFit.contain))
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
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(3)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _viewMode == 'side'
                  ? Icons.view_agenda_outlined : Icons.compare,
              color: kMuted, size: 12,
            ),
            const SizedBox(width: 5),
            Text(
              _viewMode == 'side' ? "FULL VIEW" : "SIDE BY SIDE",
              style: const TextStyle(
                  color: kMuted, fontSize: 9, letterSpacing: 1.5),
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
                _viewMode == 'side'
                    ? Icons.view_agenda_outlined : Icons.compare,
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
              SectionLabel(
                  _viewMode == 'side' ? "COMPARE" : "FULL VIEW"),
              const Spacer(),
              _viewToggle(),
            ]),
            const SizedBox(height: 10),
            _viewMode == 'side' ? _buildSideBySide() : _buildFullStacked(),
            const SizedBox(height: 20),
            // ── Groq analysis card ──
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
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 12),
                            Text(analysis!['overall'] ?? '',
                                style: const TextStyle(
                                    color: kText, fontSize: 13)),
                            const SizedBox(height: 14),
                            if ((analysis!['strengths'] as List).isNotEmpty)
                              ..._buildList("STRENGTHS",
                                  analysis!['strengths'], kGreen),
                            if ((analysis!['issues'] as List).isNotEmpty)
                              ..._buildList(
                                  "ISSUES", analysis!['issues'], kRed),
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