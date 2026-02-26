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
const kGold = Color(0xFFFFD600);
const kBg = Color(0xFF080808);
const kSurface = Color(0xFF111111);
const kCard = Color(0xFF181818);
const kBorder = Color(0xFF2A2A2A);
const kText = Color(0xFFF0F0F0);
const kMuted = Color(0xFF666666);
const kGreen = Color(0xFF4CAF50);
const kRed = Color(0xFFE53935);

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

  const GoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.outline = false,
    this.icon,
  });

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
            Text(
              label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2.5),
            ),
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
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, color: kGold),
        const SizedBox(width: 10),
        Text(text,
            style: const TextStyle(
                color: kMuted, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

PreferredSizeWidget _buildAppBar(String title) {
  return AppBar(
    backgroundColor: kSurface,
    elevation: 0,
    centerTitle: false,
    title: Row(
      children: [
        Container(width: 3, height: 16, color: kGold),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: kText, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3)),
      ],
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(color: kBorder, height: 1),
    ),
    iconTheme: const IconThemeData(color: kGold),
  );
}

/* ─────────────────────────── LOGIN SCREEN ─────────────────────────── */
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          CustomPaint(size: Size.infinite, painter: _GridPainter()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: 380,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: kBorder),
                  boxShadow: [
                    BoxShadow(
                      color: kGold.withValues(alpha: 0.08),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: kGold, borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.photo_camera, color: kBg, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text("HACKX",
                            style: TextStyle(
                                color: kText,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 6)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text("AI Photo Selector",
                        style: TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.5)),
                    const SizedBox(height: 40),
                    const SectionLabel("CREDENTIALS"),
                    const SizedBox(height: 20),
                    _buildField("USERNAME", _userCtrl, false),
                    const SizedBox(height: 16),
                    _buildField("PASSWORD", _passCtrl, _obscure,
                        suffix: IconButton(
                          icon: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility,
                              color: kMuted,
                              size: 18),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        )),
                    const SizedBox(height: 32),
                    GoldButton(
                      label: "ENTER",
                      icon: Icons.arrow_forward,
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const UploadScreen()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        "POWERED BY GROQ AI + OPENCV",  // ← updated
                        style: TextStyle(
                            color: kMuted.withValues(alpha: 0.5),
                            fontSize: 9,
                            letterSpacing: 2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
          decoration: InputDecoration(
            filled: true,
            fillColor: kCard,
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

/* ─────────────────────────── UPLOAD SCREEN ─────────────────────────── */
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<XFile> selectedImages = [];
  final ImagePicker picker = ImagePicker();

  Future<void> pickImages() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final images = await picker.pickMultiImage();
      setState(() => selectedImages = images);
    } else {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, allowMultiple: true);
      if (result != null) {
        setState(() {
          selectedImages =
              result.paths.whereType<String>().map((p) => XFile(p)).toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar("UPLOAD"),
      body: Column(
        children: [
          Container(
            color: kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.photo_library, color: kGold, size: 14),
                const SizedBox(width: 6),
                Text("${selectedImages.length} SELECTED",
                    style: const TextStyle(
                        color: kText, fontSize: 11, letterSpacing: 1.5)),
                const Spacer(),
                if (selectedImages.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => selectedImages = []),
                    child: const Text("CLEAR ALL",
                        style: TextStyle(
                            color: kMuted, fontSize: 10, letterSpacing: 2)),
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
                          width: 80,
                          height: 80,
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
                    itemBuilder: (_, i) => Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(selectedImages[i].path),
                            fit: BoxFit.cover),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => selectedImages.removeAt(i)),
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
                              builder: (_) =>
                                  ProcessingScreen(images: selectedImages),
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

/* ─────────────────────────── PROCESSING SCREEN ─────────────────────────── */
class ProcessingScreen extends StatefulWidget {
  final List<XFile> images;
  const ProcessingScreen({super.key, required this.images});
  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  List<Map<String, dynamic>> results = [];
  String? error;

  @override
  void initState() {
    super.initState();
    uploadImages();
  }

  Future<void> uploadImages() async {
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse(getUploadUrl()));
      for (var img in widget.images) {
        request.files
            .add(await http.MultipartFile.fromPath('files', img.path));
      }
      var response = await request.send();
      var body = await response.stream.bytesToString();
      var data = jsonDecode(body);
      List<Map<String, dynamic>> sorted =
          List<Map<String, dynamic>>.from(data['results']);
      sorted.sort(
          (a, b) => (b['score'] as num).compareTo(a['score'] as num));
      setState(() => results = sorted);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  String getUploadUrl() => Platform.isAndroid
      ? 'http://10.0.2.2:8000/upload-images'
      : 'http://localhost:8000/upload-images';

  String getEnhanceUrl() => Platform.isAndroid
      ? 'http://10.0.2.2:8000/enhance-image'
      : 'http://localhost:8000/enhance-image';

  String getAnalyzeUrl() => Platform.isAndroid
      ? 'http://10.0.2.2:8000/analyze-image'
      : 'http://localhost:8000/analyze-image';

  XFile findImage(String filename) =>
      widget.images.firstWhere((img) => img.name == filename);

  Color _scoreColor(double score) {
    if (score >= 70) return kGreen;
    if (score >= 45) return kGold;
    return kRed;
  }

  String _scoreLabel(double score) {
    if (score >= 70) return "EXCELLENT";
    if (score >= 50) return "GOOD";
    if (score >= 30) return "FAIR";
    return "POOR";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar("RANKED RESULTS"),
      body: error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: kRed, size: 48),
                  const SizedBox(height: 16),
                  const Text("CONNECTION FAILED",
                      style: TextStyle(
                          color: kText, fontSize: 13, letterSpacing: 2)),
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
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                            color: kGold,
                            strokeWidth: 2,
                            backgroundColor: kGold.withValues(alpha: 0.1)),
                      ),
                      const SizedBox(height: 24),
                      const Text("ANALYZING PHOTOS",
                          style: TextStyle(
                              color: kText, fontSize: 13, letterSpacing: 3)),
                      const SizedBox(height: 8),
                      const Text("Scoring sharpness, brightness, faces...",
                          style: TextStyle(color: kMuted, fontSize: 11)),
                    ],
                  ),
                )
              : Column(
                  children: [
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
                                  color: kText,
                                  fontSize: 11,
                                  letterSpacing: 1.5)),
                          const SizedBox(width: 20),
                          const Icon(Icons.emoji_events,
                              color: kGold, size: 14),
                          const SizedBox(width: 6),
                          Text("BEST: ${results.first['score']}",
                              style: const TextStyle(
                                  color: kText,
                                  fontSize: 11,
                                  letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                    const Divider(color: kBorder, height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final item = results[index];
                          final img = findImage(item['filename']);
                          final score = (item['score'] as num).toDouble();

                          return Container(
                            decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: index == 0
                                    ? kGold.withValues(alpha: 0.5)
                                    : kBorder,
                              ),
                            ),
                            child: Row(
                              children: [
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
                                  child: Text(
                                    "#${index + 1}",
                                    style: TextStyle(
                                        color: index == 0 ? kBg : kMuted,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13),
                                  ),
                                ),
                                ClipRRect(
                                  child: Image.file(File(img.path),
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['filename'],
                                        style: const TextStyle(
                                            color: kText,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3),
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
                                                  fontWeight:
                                                      FontWeight.w700),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                              "${score.toStringAsFixed(1)} / 100",
                                              style: const TextStyle(
                                                  color: kMuted,
                                                  fontSize: 11)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(2),
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
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EnhancingScreen(
                                          img: img,
                                          enhanceUrl: getEnhanceUrl(),
                                          analyzeUrl: getAnalyzeUrl(),
                                        ),
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        border:
                                            Border.all(color: kGold),
                                        borderRadius:
                                            BorderRadius.circular(3),
                                      ),
                                      child: const Column(
                                        children: [
                                          Icon(Icons.auto_fix_high,
                                              color: kGold, size: 16),
                                          SizedBox(height: 4),
                                          Text("FIX",
                                              style: TextStyle(
                                                  color: kGold,
                                                  fontSize: 9,
                                                  letterSpacing: 1.5,
                                                  fontWeight:
                                                      FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                  ),
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

/* ─────────────────────────── ENHANCING SCREEN ─────────────────────────── */
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
  String? error;
  String method = "";
  bool loadingAnalysis = true;

  @override
  void initState() {
    super.initState();
    enhance();
    analyzeWithGroq();
  }

  Future<void> enhance() async {
    try {
      final bytes = await File(widget.img.path).readAsBytes();
      var request =
          http.MultipartRequest('POST', Uri.parse(widget.enhanceUrl));
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: widget.img.name));
      var response = await request.send();
      var body = jsonDecode(await response.stream.bytesToString());
      setState(() {
        enhancedBytes = base64Decode(body['enhanced']);
        method = body['method'] == 'ai'
            ? 'AI ENHANCED — GROQ'          // ← updated
            : 'ENHANCED — OPENCV';
      });
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> analyzeWithGroq() async {   // ← renamed method
    try {
      final bytes = await File(widget.img.path).readAsBytes();
      var request =
          http.MultipartRequest('POST', Uri.parse(widget.analyzeUrl));
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: widget.img.name));
      var response = await request.send();
      var body = jsonDecode(await response.stream.bytesToString());
      setState(() {
        analysis = body['analysis'];
        loadingAnalysis = false;
      });
    } catch (e) {
      setState(() => loadingAnalysis = false);
    }
  }

  List<Widget> _buildList(String title, List items, Color color) {
    return [
      Text(title,
          style: TextStyle(
              color: color,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w700)),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar("ENHANCEMENT"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* ── GROQ ANALYSIS CARD ── */
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: kGold.withValues(alpha: 0.4)),
              ),
              child: loadingAnalysis
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: kGold, strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text("GROQ ANALYZING...",        // ← updated
                            style: TextStyle(
                                color: kGold,
                                fontSize: 11,
                                letterSpacing: 2)),
                      ],
                    )
                  : analysis == null
                      ? const Text("Analysis unavailable",
                          style: TextStyle(color: kMuted))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome,
                                    color: kGold, size: 14),
                                const SizedBox(width: 8),
                                const Text("GROQ AI ANALYSIS",   // ← updated
                                    style: TextStyle(
                                        color: kGold,
                                        fontSize: 11,
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
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
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lightbulb_outline,
                                        color: kGold, size: 14),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(analysis!['tip'],
                                          style: const TextStyle(
                                              color: kGold, fontSize: 11)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
            ),

            const SizedBox(height: 20),

            /* ── ORIGINAL ── */
            const SectionLabel("ORIGINAL"),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(File(widget.img.path),
                  width: double.infinity, fit: BoxFit.cover),
            ),

            const SizedBox(height: 20),

            /* ── ENHANCED ── */
            const SectionLabel("ENHANCED"),
            const SizedBox(height: 4),
            if (method.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: kGold.withValues(alpha: 0.1),
                  border:
                      Border.all(color: kGold.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(method,
                    style: const TextStyle(
                        color: kGold, fontSize: 9, letterSpacing: 2)),
              ),
            enhancedBytes == null
                ? Container(
                    height: 200,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: kBorder)),
                    child: const CircularProgressIndicator(
                        color: kGold, strokeWidth: 2),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(enhancedBytes!,
                        width: double.infinity, fit: BoxFit.cover),
                  ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────────── GRID PAINTER ─────────────────────────── */
class _GridPainter extends CustomPainter {
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