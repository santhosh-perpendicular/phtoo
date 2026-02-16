import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const PhotoSelectorApp());
}

/* ------------------- APP ------------------- */
class PhotoSelectorApp extends StatelessWidget {
  const PhotoSelectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "PhotoSelector",
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0B),
        primaryColor: const Color(0xFFFFD600),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0B0B),
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFFFFD600),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          iconTheme: IconThemeData(color: Color(0xFFFFD600)),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD600),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF151515),
          labelStyle: const TextStyle(color: Color(0xFFFFD600)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFFD600)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFFFD600),
              width: 2,
            ),
          ),
        ),

        // ✅ FIXED: CardThemeData
        cardTheme: CardThemeData(
          color: const Color(0xFF121212),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

/* ------------------- LOGIN SCREEN ------------------- */
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFFD600),
              width: 1.5,
            ),
            boxShadow: [
              // ✅ FIXED: withValues
              BoxShadow(
                color: const Color(0xFFFFD600).withValues(alpha: 0.25),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "LOGIN",
                style: TextStyle(
                  color: Color(0xFFFFD600),
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Username"),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Password"),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UploadScreen(),
                      ),
                    );
                  },
                  child: const Text("ENTER"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------- UPLOAD SCREEN ------------------- */
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
      selectedImages = await picker.pickMultiImage();
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null) {
        selectedImages = result.paths
            .whereType<String>()
            .map((p) => XFile(p))
            .toList();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("UPLOAD PHOTOS")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: pickImages,
            child: const Text("SELECT FILES"),
          ),
          Text(
            "FILES SELECTED: ${selectedImages.length}",
            style: const TextStyle(color: Color(0xFFFFD600)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: selectedImages.length,
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(selectedImages[i].path),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          ElevatedButton(
            child: const Text("UPLOAD & ANALYZE"),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProcessingScreen(images: selectedImages),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/* ------------------- PROCESSING SCREEN ------------------- */
class ProcessingScreen extends StatefulWidget {
  final List<XFile> images;
  const ProcessingScreen({super.key, required this.images});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  List<Map<String, dynamic>> results = [];

  @override
  void initState() {
    super.initState();
    uploadImages();
  }

  Future<void> uploadImages() async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(getBaseUrl()),
    );

    for (var img in widget.images) {
      request.files.add(
        await http.MultipartFile.fromPath('files', img.path),
      );
    }

    var response = await request.send();
    var body = await response.stream.bytesToString();
    var data = jsonDecode(body);

    List<Map<String, dynamic>> sorted =
        List<Map<String, dynamic>>.from(data['results']);

    sorted.sort(
      (a, b) => (b['score'] as num).compareTo(a['score'] as num),
    );

    setState(() => results = sorted);
  }

  String getBaseUrl() {
    return Platform.isAndroid
        ? 'http://10.0.2.2:8000/upload-images'
        : 'http://localhost:8000/upload-images';
  }

  XFile findImage(String filename) {
    return widget.images.firstWhere(
      (img) => img.name == filename,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("RANKED PHOTOS")),
      body: results.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFD600),
              ),
            )
          : ListView.builder(
              itemCount: results.length,
              itemBuilder: (_, index) {
                final item = results[index];
                final img = findImage(item['filename']);

                return Card(
                  margin: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.topLeft,
                        children: [
                          Image.file(
                            File(img.path),
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            color: const Color(0xFFFFD600),
                            child: Text(
                              "#${index + 1}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['filename'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text("Score: ${item['score']}"),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
